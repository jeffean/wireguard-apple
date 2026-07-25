// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

@main
private enum TunnelConfigurationMigrationTests {
    static func main() {
        testProviderConfigurationMigration()
        testMigrationSavesWaitForCompletion()
        testMigrationSaveFailureIncludesTunnelName()
        print("PASS: TunnelConfigurationMigrationTests")
    }

    private static func testProviderConfigurationMigration() {
        let result = TunnelProviderConfigurationMigrator.migrate(
            [
                "WgQuickConfig": "legacy",
                "UnrelatedKey": "preserved",
            ],
            tunnelName: "Home"
        )

        expect(result.didChange, "Legacy provider configuration reports a migration")
        expect(result.providerConfiguration["WgQuickConfig"] == nil, "Legacy config is removed")
        expect(
            result.providerConfiguration["UnrelatedKey"] as? String == "preserved",
            "Unrelated provider configuration is preserved"
        )
        expect(
            result.providerConfiguration["TunnelName"] as? String == "Home",
            "Tunnel name is persisted"
        )
    }

    private static func testMigrationSavesWaitForCompletion() {
        var saveCompletion: ((Error?) -> Void)?
        var didComplete = false
        let operation = TunnelMigrationSaveOperation(name: "Home") { completion in
            saveCompletion = completion
        }

        TunnelMigrationSaveCoordinator.saveAll([operation]) { result in
            if case .success = result {
                didComplete = true
            }
        }

        expect(!didComplete, "Coordinator waits for saveToPreferences completion")
        saveCompletion?(nil)
        expect(didComplete, "Coordinator completes after preferences are saved")
    }

    private static func testMigrationSaveFailureIncludesTunnelName() {
        let expectedError = NSError(domain: "MigrationTests", code: 7)
        var receivedFailure: TunnelMigrationSaveFailure?
        let operation = TunnelMigrationSaveOperation(name: "Office") { completion in
            completion(expectedError)
        }

        TunnelMigrationSaveCoordinator.saveAll([operation]) { result in
            if case let .failure(failure) = result {
                receivedFailure = failure
            }
        }

        expect(receivedFailure?.tunnelName == "Office", "Failure identifies the tunnel")
        expect(
            (receivedFailure?.underlyingError as NSError?) == expectedError,
            "Failure preserves the complete underlying error"
        )
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard condition() else {
            fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
            exit(1)
        }
    }
}
