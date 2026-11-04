// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import SwiftUI
import WidgetKit

struct WireGuardStatusWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TunnelWidgetSnapshot
}

struct WireGuardStatusWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> WireGuardStatusWidgetEntry {
        sampleEntry()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (WireGuardStatusWidgetEntry) -> Void
    ) {
        // The widget gallery shows a representative connected state instead
        // of whatever the device happens to be doing right now.
        completion(context.isPreview ? sampleEntry() : entry())
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<WireGuardStatusWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> WireGuardStatusWidgetEntry {
        WireGuardStatusWidgetEntry(
            date: Date(),
            snapshot: TunnelWidgetSnapshotStore().load()
        )
    }

    private func sampleEntry() -> WireGuardStatusWidgetEntry {
        let now = Date()
        return WireGuardStatusWidgetEntry(
            date: now,
            snapshot: TunnelWidgetSnapshot(
                status: .connected,
                tunnelName: "Office VPN",
                route: TunnelWidgetRouteSummarizer.summarize(
                    peers: [TunnelWidgetPeerRoutes(allowedIPs: ["0.0.0.0/0", "::/0"], endpointHost: "vpn.example.com")],
                    dnsServers: ["10.0.0.53"]
                ),
                updatedAt: now.addingTimeInterval(-42 * 60)
            )
        )
    }
}

struct WireGuardStatusWidget: Widget {
    let kind = "TunnelStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WireGuardStatusWidgetProvider()
        ) { entry in
            WireGuardStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Tunnel Status")
        .description("See the current WireGuard tunnel status.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [
                .systemSmall,
                .systemMedium,
                .accessoryCircular,
                .accessoryRectangular,
                .accessoryInline
            ]
        }
        return [.systemSmall, .systemMedium]
    }
}

@main
struct WireGuardStatusWidgetBundle: WidgetBundle {
    var body: some Widget {
        WireGuardStatusWidget()
    }
}
