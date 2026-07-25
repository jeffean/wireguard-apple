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
    static func saveAll(
        _ operations: [TunnelMigrationSaveOperation],
        completion: @escaping (Result<Void, TunnelMigrationSaveFailure>) -> Void
    ) {
        save(operations[...], completion: completion)
    }

    private static func save(
        _ operations: ArraySlice<TunnelMigrationSaveOperation>,
        completion: @escaping (Result<Void, TunnelMigrationSaveFailure>) -> Void
    ) {
        guard let operation = operations.first else {
            completion(.success(()))
            return
        }

        operation.save { error in
            if let error {
                completion(
                    .failure(
                        TunnelMigrationSaveFailure(
                            tunnelName: operation.name,
                            underlyingError: error
                        )
                    )
                )
                return
            }
            save(operations.dropFirst(), completion: completion)
        }
    }
}
