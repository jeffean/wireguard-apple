// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

@main
private enum TunnelConfigurationMigrationTests {
    static func main() {
        testProviderConfigurationMigration()
        testMigrationSavesWaitForCompletion()
        testMigrationSaveRetriesOnceThenSucceeds()
        testMigrationSaveReturnsExhaustedFailures()
        testAvailabilityWaitsForExhaustedAttempts()
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

        TunnelMigrationSaveCoordinator.saveAllBeforeAvailability(
            [operation],
            maxAttempts: 2
        ) { failures in
            expect(failures.isEmpty, "Successful save has no exhausted failures")
            didComplete = true
        }

        expect(!didComplete, "Coordinator waits for saveToPreferences completion")
        saveCompletion?(nil)
        expect(didComplete, "Coordinator completes after preferences are saved")
    }

    private static func testMigrationSaveRetriesOnceThenSucceeds() {
        let firstError = NSError(domain: "MigrationTests", code: 6)
        var attempts = 0
        var receivedFailures: [TunnelMigrationSaveFailure]?
        let operation = TunnelMigrationSaveOperation(name: "Home") { completion in
            attempts += 1
            completion(attempts == 1 ? firstError : nil)
        }

        TunnelMigrationSaveCoordinator.saveAllBeforeAvailability(
            [operation],
            maxAttempts: 2
        ) { failures in
            receivedFailures = failures
        }

        expect(attempts == 2, "A failed metadata save is retried once")
        expect(receivedFailures?.isEmpty == true, "A successful retry clears the failure")
    }

    private static func testMigrationSaveReturnsExhaustedFailures() {
        let expectedError = NSError(domain: "MigrationTests", code: 7)
        var attempts = 0
        var receivedFailures: [TunnelMigrationSaveFailure]?
        let operation = TunnelMigrationSaveOperation(name: "Office") { completion in
            attempts += 1
            completion(expectedError)
        }

        TunnelMigrationSaveCoordinator.saveAllBeforeAvailability(
            [operation],
            maxAttempts: 2
        ) { failures in
            receivedFailures = failures
        }

        expect(attempts == 2, "Metadata save retries are bounded")
        expect(receivedFailures?.count == 1, "An exhausted save returns one failure for logging")
        expect(receivedFailures?.first?.tunnelName == "Office", "Failure identifies the tunnel")
        expect(
            (receivedFailures?.first?.underlyingError as NSError?) == expectedError,
            "Failure preserves the complete underlying error"
        )
    }

    private static func testAvailabilityWaitsForExhaustedAttempts() {
        let expectedError = NSError(domain: "MigrationTests", code: 8)
        var attemptCompletions: [(Error?) -> Void] = []
        var availabilityFailures: [TunnelMigrationSaveFailure]?
        let operation = TunnelMigrationSaveOperation(name: "Work") { completion in
            attemptCompletions.append(completion)
        }

        TunnelMigrationSaveCoordinator.saveAllBeforeAvailability(
            [operation],
            maxAttempts: 2
        ) { failures in
            availabilityFailures = failures
        }

        expect(attemptCompletions.count == 1, "First metadata save attempt starts")
        expect(availabilityFailures == nil, "Availability waits for the first attempt")
        attemptCompletions[0](expectedError)
        expect(attemptCompletions.count == 2, "A second bounded attempt starts")
        expect(availabilityFailures == nil, "Availability waits for the retry")
        attemptCompletions[1](expectedError)
        expect(
            availabilityFailures?.first?.tunnelName == "Work",
            "Availability continues after retry exhaustion with failures for logging"
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
