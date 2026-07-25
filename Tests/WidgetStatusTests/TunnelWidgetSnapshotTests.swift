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

        let firstProcessClock = TestTransitionClock(
            transition: TunnelWidgetTransitionOrder(
                bootSessionIdentifier: "boot-a",
                monotonicTimestamp: 100
            )
        )
        let secondProcessClock = TestTransitionClock(
            transition: TunnelWidgetTransitionOrder(
                bootSessionIdentifier: "boot-a",
                monotonicTimestamp: 300
            )
        )
        let store = TunnelWidgetSnapshotStore(
            backend: TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL),
            transitionClock: firstProcessClock
        )
        let otherProcessStore = TunnelWidgetSnapshotStore(
            backend: TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL),
            transitionClock: secondProcessClock
        )
        let firstContentDate = Date(timeIntervalSince1970: 1_721_868_800)
        let suppressedContentDate = Date(timeIntervalSince1970: 1_721_868_860)
        let newBootContentDate = Date(timeIntervalSince1970: 1_721_868_920)

        expect(store.load().status == .disconnected, "Missing data falls back to disconnected")
        expect(
            store.saveIfChanged(status: .connected, tunnelName: "Home", now: firstContentDate),
            "First value is saved"
        )
        expect(
            !otherProcessStore.saveIfChanged(
                status: .connected,
                tunnelName: "Home",
                now: suppressedContentDate
            ),
            "Equivalent content is not rewritten"
        )
        expect(store.load().tunnelName == "Home", "Saved snapshot round trips")
        expect(
            store.load().updatedAt == firstContentDate,
            "Equivalent content preserves the content-change timestamp"
        )
        expect(
            store.load().transitionOrder?.monotonicTimestamp == 300,
            "Equivalent content advances the causal watermark"
        )

        secondProcessClock.transition = TunnelWidgetTransitionOrder(
            bootSessionIdentifier: "boot-a",
            monotonicTimestamp: 200
        )
        expect(
            !otherProcessStore.saveIfChanged(
                status: .disconnecting,
                tunnelName: "Home",
                now: suppressedContentDate
            ),
            "A delayed transition behind the watermark is rejected"
        )
        expect(store.load().status == .connected, "A delayed transition cannot replace current content")

        secondProcessClock.transition = TunnelWidgetTransitionOrder(
            bootSessionIdentifier: "boot-b",
            monotonicTimestamp: 1
        )
        expect(
            otherProcessStore.saveIfChanged(
                status: .disconnecting,
                tunnelName: "Home",
                now: newBootContentDate
            ),
            "A transition from a new boot session is accepted"
        )
        expect(store.load().status == .disconnecting, "New boot content is stored")
        expect(store.load().updatedAt == newBootContentDate, "New boot updates content-change time")

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

private final class TestTransitionClock: TunnelWidgetTransitionClock {
    var transition: TunnelWidgetTransitionOrder

    init(transition: TunnelWidgetTransitionOrder) {
        self.transition = transition
    }

    func now() -> TunnelWidgetTransitionOrder {
        transition
    }
}
