// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

enum TunnelProviderConfigurationMigrator {
    static let tunnelNameKey = "TunnelName"
    static let legacyConfigurationKey = "WgQuickConfig"

    struct Result {
        let providerConfiguration: [String: Any]
        let didChange: Bool
    }

    static func migrate(
        _ providerConfiguration: [String: Any]?,
        tunnelName: String
    ) -> Result {
        var migratedConfiguration = providerConfiguration ?? [:]
        let removedLegacyConfiguration =
            migratedConfiguration.removeValue(forKey: legacyConfigurationKey) != nil
        let changedTunnelName = migratedConfiguration[tunnelNameKey] as? String != tunnelName
        migratedConfiguration[tunnelNameKey] = tunnelName
        return Result(
            providerConfiguration: migratedConfiguration,
            didChange: removedLegacyConfiguration || changedTunnelName
        )
    }
}

struct TunnelMigrationSaveOperation {
    let name: String
    let save: (@escaping (Error?) -> Void) -> Void
}

struct TunnelMigrationSaveFailure: Error {
    let tunnelName: String
    let underlyingError: Error
}

enum TunnelMigrationSaveCoordinator {
    static func saveAllBeforeAvailability(
        _ operations: [TunnelMigrationSaveOperation],
        maxAttempts: Int,
        availabilityContinuation: @escaping ([TunnelMigrationSaveFailure]) -> Void
    ) {
        save(
            operations[...],
            maxAttempts: max(1, maxAttempts),
            failures: [],
            completion: availabilityContinuation
        )
    }

    private static func save(
        _ operations: ArraySlice<TunnelMigrationSaveOperation>,
        maxAttempts: Int,
        failures: [TunnelMigrationSaveFailure],
        completion: @escaping ([TunnelMigrationSaveFailure]) -> Void
    ) {
        guard let operation = operations.first else {
            completion(failures)
            return
        }

        attempt(operation, remainingAttempts: maxAttempts) { failure in
            var updatedFailures = failures
            if let failure {
                updatedFailures.append(failure)
            }
            save(
                operations.dropFirst(),
                maxAttempts: maxAttempts,
                failures: updatedFailures,
                completion: completion
            )
        }
    }

    private static func attempt(
        _ operation: TunnelMigrationSaveOperation,
        remainingAttempts: Int,
        completion: @escaping (TunnelMigrationSaveFailure?) -> Void
    ) {
        operation.save { error in
            guard let error else {
                completion(nil)
                return
            }
            guard remainingAttempts > 1 else {
                completion(
                    TunnelMigrationSaveFailure(
                        tunnelName: operation.name,
                        underlyingError: error
                    )
                )
                return
            }
            attempt(
                operation,
                remainingAttempts: remainingAttempts - 1,
                completion: completion
            )
        }
    }
}
