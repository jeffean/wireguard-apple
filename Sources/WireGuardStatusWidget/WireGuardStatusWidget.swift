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
        WireGuardStatusWidgetEntry(
            date: Date(),
            snapshot: TunnelWidgetSnapshot(
                status: .connected,
                tunnelName: "WireGuard",
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (WireGuardStatusWidgetEntry) -> Void
    ) {
        completion(entry())
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WireGuardStatusWidgetBundle: WidgetBundle {
    var body: some Widget {
        WireGuardStatusWidget()
    }
}
