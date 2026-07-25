// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import SwiftUI
import WidgetKit

struct WireGuardStatusWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: WireGuardStatusWidgetEntry

    var body: some View {
        Group {
            if widgetFamily == .systemMedium {
                HStack(spacing: 16) {
                    statusIcon
                    statusDetails
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    statusIcon
                    Spacer(minLength: 0)
                    statusDetails
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    private var statusIcon: some View {
        Image(systemName: style.symbolName)
            .font(.system(.title, design: .rounded).weight(.semibold))
            .foregroundColor(style.color)
            .accessibilityHidden(true)
    }

    private var statusDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(style.title)
                .font(.headline)
                .foregroundColor(.primary)

            if entry.snapshot.status != .disconnected {
                Text(tunnelName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var tunnelName: String {
        guard let tunnelName = entry.snapshot.tunnelName, !tunnelName.isEmpty else {
            return "Tunnel"
        }
        return tunnelName
    }

    private var style: StatusStyle {
        switch entry.snapshot.status {
        case .connected:
            return StatusStyle(
                title: "Connected",
                symbolName: "checkmark.shield.fill",
                color: .green
            )
        case .connecting:
            return StatusStyle(
                title: "Connecting",
                symbolName: "arrow.triangle.2.circlepath",
                color: .orange
            )
        case .disconnecting:
            return StatusStyle(
                title: "Disconnecting",
                symbolName: "arrow.triangle.2.circlepath",
                color: .orange
            )
        case .disconnected:
            return StatusStyle(
                title: "Disconnected",
                symbolName: "shield.slash.fill",
                color: .gray
            )
        }
    }
}

private struct StatusStyle {
    let title: String
    let symbolName: String
    let color: Color
}
