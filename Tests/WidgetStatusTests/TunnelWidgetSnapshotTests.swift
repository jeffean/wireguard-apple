import Foundation

@main
private enum TunnelWidgetSnapshotTests {
    static func main() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelWidgetSnapshotTests.\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = temporaryDirectory.appendingPathComponent("snapshot.json")
        try? FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let store = TunnelWidgetSnapshotStore(
            backend: TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL)
        )
        let otherProcessStore = TunnelWidgetSnapshotStore(
            backend: TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL)
        )
        let firstDate = Date(timeIntervalSince1970: 1_721_868_800)
        let secondDate = Date(timeIntervalSince1970: 1_721_868_860)
        let newerDate = Date(timeIntervalSince1970: 1_721_868_920)
        let olderDate = Date(timeIntervalSince1970: 1_721_868_900)

        expect(store.load().status == .disconnected, "Missing data falls back to disconnected")
        expect(
            store.saveIfChanged(status: .connected, tunnelName: "Home", now: firstDate),
            "First value is saved"
        )
        expect(
            !otherProcessStore.saveIfChanged(status: .connected, tunnelName: "Home", now: secondDate),
            "Equivalent content is not rewritten"
        )
        expect(store.load().tunnelName == "Home", "Saved snapshot round trips")
        expect(
            store.load().updatedAt == firstDate, "Equivalent content preserves the original timestamp"
        )
        expect(
            store.saveIfChanged(status: .disconnecting, tunnelName: "Home", now: newerDate),
            "Newer content is saved"
        )
        expect(
            !otherProcessStore.saveIfChanged(status: .connected, tunnelName: "Home", now: olderDate),
            "An older transition is rejected"
        )
        expect(store.load().status == .disconnecting, "An older transition cannot replace newer content")
        expect(store.load().updatedAt == newerDate, "An older transition preserves the newer timestamp")

        try? Data("not-json".utf8).write(to: snapshotURL, options: .atomic)
        expect(store.load().status == .disconnected, "Invalid data falls back to disconnected")

        print("PASS: TunnelWidgetSnapshotTests")
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
