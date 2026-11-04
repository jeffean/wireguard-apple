import Foundation

@main
private enum TunnelWidgetSnapshotTests {
    static func main() {
        testProductionBootSessionIdentifier()
        testUnavailableBootSessionIdentity()
        testUnavailableOrderingAcceptsNewBootContent()
        testRouteSummaries()
        testRouteChangeIsContentChange()

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

    private static func testRouteSummaries() {
        let full = TunnelWidgetRouteSummarizer.summarize(
            peers: [
                TunnelWidgetPeerRoutes(allowedIPs: ["10.8.0.0/24"], endpointHost: "lab.example.com"),
                TunnelWidgetPeerRoutes(allowedIPs: ["0.0.0.0/0", "::/0"], endpointHost: "exit.example.com")
            ],
            dnsServers: ["10.0.0.53"]
        )
        expect(full.mode == .allTraffic, "A default route means all traffic")
        expect(full.endpointHost == "exit.example.com", "The exit endpoint is the peer with the default route")
        expect(full.routesIPv6, "::/0 routes IPv6")
        expect(full.dnsServers == ["10.0.0.53"], "DNS servers are kept")

        let halves = TunnelWidgetRouteSummarizer.summarize(
            peers: [TunnelWidgetPeerRoutes(allowedIPs: ["0.0.0.0/1", "128.0.0.0/1"], endpointHost: "203.0.113.5")],
            dnsServers: []
        )
        expect(halves.mode == .allTraffic, "Two /1 halves cover all IPv4 traffic")
        expect(!halves.routesIPv6, "IPv4-only routes leave IPv6 outside the tunnel")

        let excludingLAN = TunnelWidgetRouteSummarizer.summarize(
            peers: [
                TunnelWidgetPeerRoutes(
                    allowedIPs: ["::/0"] + TunnelWidgetRouteSummarizer.publicIPv4Ranges + ["10.0.0.53/32"],
                    endpointHost: "vpn.example.com"
                )
            ],
            dnsServers: ["10.0.0.53"]
        )
        expect(excludingLAN.mode == .allTrafficExcludingLAN, "Exclude private IPs is all traffic without LAN")
        expect(excludingLAN.endpointHost == "vpn.example.com", "Excluded-LAN tunnels report their exit endpoint")

        let split = TunnelWidgetRouteSummarizer.summarize(
            peers: [TunnelWidgetPeerRoutes(allowedIPs: ["fd00::/64", "10.0.0.0/8", "192.168.50.0/24"], endpointHost: "lab.example.com")],
            dnsServers: []
        )
        expect(split.mode == .split, "Private subnets are a split tunnel")
        expect(split.firstRoute == "10.0.0.0/8", "Split tunnels show an IPv4 route first")
        expect(split.routeCount == 3, "Split tunnels count every route")
        expect(split.endpointHost == "lab.example.com", "Split tunnels fall back to the first endpoint")
    }

    private static func testRouteChangeIsContentChange() {
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelWidgetRouteTests.\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: snapshotURL)
        }
        let backend = TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL)
        let store = TunnelWidgetSnapshotStore(backend: backend, transitionClock: NilTransitionClock())
        let splitRoute = TunnelWidgetRouteSummarizer.summarize(
            peers: [TunnelWidgetPeerRoutes(allowedIPs: ["10.0.0.0/8"], endpointHost: nil)],
            dnsServers: []
        )
        let fullRoute = TunnelWidgetRouteSummarizer.summarize(
            peers: [TunnelWidgetPeerRoutes(allowedIPs: ["0.0.0.0/0"], endpointHost: nil)],
            dnsServers: []
        )
        let start = Date(timeIntervalSince1970: 1_000)
        expect(store.saveIfChanged(status: .connected, tunnelName: "Home", route: splitRoute, now: start), "First route is saved")
        expect(
            !store.saveIfChanged(status: .connected, tunnelName: "Home", route: splitRoute, now: start.addingTimeInterval(60)),
            "The same route is not a content change"
        )
        expect(backend.load()?.updatedAt == start, "An unchanged route keeps the connection start time")
        expect(store.saveIfChanged(status: .connected, tunnelName: "Home", route: fullRoute, now: start.addingTimeInterval(120)), "A new route is a content change")
        expect(backend.load()?.route == fullRoute, "The new route is stored")
    }

    private static func testProductionBootSessionIdentifier() {
        let firstIdentifier = DarwinBootSessionProvider().identifier()
        let secondIdentifier = DarwinBootSessionProvider().identifier()

        expect(firstIdentifier != nil, "Darwin exposes a boot session identifier")
        expect(firstIdentifier == secondIdentifier, "Boot session identifier is system-global")
        expect(
            firstIdentifier.flatMap(UUID.init(uuidString:)) != nil,
            "Boot session identifier is a valid UUID"
        )
    }

    private static func testUnavailableBootSessionIdentity() {
        let clock = TunnelWidgetSystemTransitionClock(
            bootSessionIdentifierProvider: UnavailableBootSessionIdentifierProvider()
        )

        expect(clock.now() == nil, "An unavailable boot identity produces no transition order")
    }

    private static func testUnavailableOrderingAcceptsNewBootContent() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "TunnelWidgetUnavailableOrderingTests.\(UUID().uuidString)",
                isDirectory: true
            )
        let snapshotURL = temporaryDirectory.appendingPathComponent("snapshot.json")
        try? FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let backend = TunnelWidgetSnapshotFileBackend(fileURL: snapshotURL)
        let oldBootDate = Date(timeIntervalSince1970: 1_721_868_800)
        let newBootDate = Date(timeIntervalSince1970: 1_721_868_860)
        let reliableDate = Date(timeIntervalSince1970: 1_721_868_920)
        expect(
            backend.save(
                TunnelWidgetSnapshot(
                    status: .connected,
                    tunnelName: "Home",
                    updatedAt: oldBootDate,
                    transitionOrder: TunnelWidgetTransitionOrder(
                        bootSessionIdentifier: "old-boot",
                        monotonicTimestamp: 100_000
                    )
                )
            ) == .contentChanged,
            "The old boot watermark is persisted"
        )

        let unavailableStore = TunnelWidgetSnapshotStore(
            backend: backend,
            transitionClock: TunnelWidgetSystemTransitionClock(
                bootSessionIdentifierProvider: UnavailableBootSessionIdentifierProvider()
            )
        )
        expect(
            unavailableStore.saveIfChanged(
                status: .disconnecting,
                tunnelName: "Home",
                now: newBootDate
            ),
            "Unavailable ordering does not reject different new-boot content"
        )
        expect(backend.load()?.status == .disconnecting, "New-boot content replaces the old snapshot")
        expect(backend.load()?.transitionOrder == nil, "Unavailable ordering is persisted as unavailable")
        expect(
            !unavailableStore.saveIfChanged(
                status: .disconnecting,
                tunnelName: "Home",
                now: newBootDate.addingTimeInterval(30)
            ),
            "Equivalent content suppresses reload when ordering is unavailable"
        )
        expect(
            backend.load()?.updatedAt == newBootDate,
            "Equivalent unavailable-order content preserves the content-change timestamp"
        )

        let reliableClock = TestTransitionClock(
            transition: TunnelWidgetTransitionOrder(
                bootSessionIdentifier: "new-boot",
                monotonicTimestamp: 2
            )
        )
        let reliableStore = TunnelWidgetSnapshotStore(
            backend: backend,
            transitionClock: reliableClock
        )
        expect(
            reliableStore.saveIfChanged(
                status: .disconnected,
                tunnelName: nil,
                now: reliableDate
            ),
            "Reliable ordering resumes after an unavailable transition"
        )
        reliableClock.transition = TunnelWidgetTransitionOrder(
            bootSessionIdentifier: "new-boot",
            monotonicTimestamp: 1
        )
        expect(
            !reliableStore.saveIfChanged(
                status: .connected,
                tunnelName: "Home",
                now: reliableDate.addingTimeInterval(60)
            ),
            "Resumed reliable ordering rejects a stale transition"
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

private final class TestTransitionClock: TunnelWidgetTransitionClock {
    var transition: TunnelWidgetTransitionOrder?

    init(transition: TunnelWidgetTransitionOrder?) {
        self.transition = transition
    }

    func now() -> TunnelWidgetTransitionOrder? {
        transition
    }
}

private struct UnavailableBootSessionIdentifierProvider: WidgetBootSessionProvider {
    func identifier() -> String? {
        nil
    }
}

private struct NilTransitionClock: TunnelWidgetTransitionClock {
    func now() -> TunnelWidgetTransitionOrder? {
        nil
    }
}
