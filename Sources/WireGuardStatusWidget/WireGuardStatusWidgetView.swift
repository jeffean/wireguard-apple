// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import SwiftUI
import WidgetKit

struct WireGuardStatusWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: WireGuardStatusWidgetEntry

    var body: some View {
        TunnelStatusContentView(snapshot: entry.snapshot, family: widgetFamily)
            .widgetContainerBackground(isAccessory: widgetFamily.isAccessory) {
                StatusBackground(style: StatusStyle(status: entry.snapshot.status))
            }
    }
}

/// Renders the widget content for an explicit family so the layout does not
/// depend on the read-only `widgetFamily` environment value.
struct TunnelStatusContentView: View {
    let snapshot: TunnelWidgetSnapshot
    let family: WidgetFamily

    private var style: StatusStyle {
        StatusStyle(status: snapshot.status)
    }

    var body: some View {
        if #available(iOSApplicationExtension 16.0, *) {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        } else if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    // MARK: - Home Screen

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusBadge(style: style, diameter: 44)
            Spacer(minLength: 8)
            Text(style.title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            detailText
                .font(.subheadline.weight(.medium))
                .padding(.top, 1)
            if let connectedSince {
                Label {
                    Text(connectedSince, style: .timer)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(style.tint)
                .lineLimit(1)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            StatusBadge(style: style, diameter: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("WireGuard")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(style.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                detailText
                    .font(.subheadline.weight(.medium))
            }
            Spacer(minLength: 8)
            if let connectedSince {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Uptime")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(connectedSince, style: .timer)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(style.tint)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                // WidgetKit reports a timer's ideal width as unbounded, so it
                // needs an explicit width instead of fixedSize().
                .frame(width: 92, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lock Screen

    @available(iOSApplicationExtension 16.0, *)
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: style.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(style.title))
    }

    @available(iOSApplicationExtension 16.0, *)
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label {
                Text(style.title)
            } icon: {
                Image(systemName: style.symbolName)
            }
            .font(.headline)
            .widgetAccentable()
            detailText
                .font(.subheadline)
            if let connectedSince {
                Text(connectedSince, style: .timer)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @available(iOSApplicationExtension 16.0, *)
    private var inlineView: some View {
        Label {
            if snapshot.status == .disconnected {
                Text(style.title)
            } else {
                Text(style.title) + Text(" · ") + Text(verbatim: tunnelName)
            }
        } icon: {
            Image(systemName: style.symbolName)
        }
    }

    // MARK: - Shared Pieces

    @ViewBuilder
    private var detailText: some View {
        if snapshot.status == .disconnected {
            Text("No active tunnel")
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else {
            Text(verbatim: tunnelName)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var tunnelName: String {
        guard let tunnelName = snapshot.tunnelName, !tunnelName.isEmpty else {
            return "Tunnel"
        }
        return tunnelName
    }

    /// The snapshot only changes `updatedAt` when its content changes, so a
    /// connected snapshot records when the current connection began.
    private var connectedSince: Date? {
        guard snapshot.status == .connected,
              snapshot.updatedAt > Date(timeIntervalSince1970: 0),
              snapshot.updatedAt <= Date()
        else {
            return nil
        }
        return snapshot.updatedAt
    }
}

struct StatusStyle {
    let title: LocalizedStringKey
    let symbolName: String
    let tint: Color
    let isActive: Bool

    init(status: TunnelWidgetStatus) {
        switch status {
        case .connected:
            title = "Connected"
            symbolName = "lock.shield.fill"
            tint = .green
            isActive = true
        case .connecting:
            title = "Connecting"
            symbolName = "arrow.triangle.2.circlepath"
            tint = .orange
            isActive = true
        case .disconnecting:
            title = "Disconnecting"
            symbolName = "arrow.triangle.2.circlepath"
            tint = .orange
            isActive = true
        case .disconnected:
            title = "Disconnected"
            symbolName = "shield.slash.fill"
            tint = Color(uiColor: .systemGray)
            isActive = false
        }
    }
}

struct StatusBadge: View {
    let style: StatusStyle
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(style.tint.opacity(style.isActive ? 0.2 : 0.14))
            Image(systemName: style.symbolName)
                .font(.system(size: diameter * 0.45, weight: .semibold))
                .foregroundColor(style.tint)
        }
        .frame(width: diameter, height: diameter)
        .widgetAccentableIfAvailable()
        .accessibilityHidden(true)
    }
}

struct StatusBackground: View {
    let style: StatusStyle

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(
                colors: [
                    style.tint.opacity(style.isActive ? 0.24 : 0.1),
                    style.tint.opacity(0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private extension WidgetFamily {
    var isAccessory: Bool {
        guard #available(iOSApplicationExtension 16.0, *) else {
            return false
        }
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }
}

private extension View {
    /// Uses the iOS 17 container background API, which also lets the system
    /// apply its own content margins and remove the background in StandBy and
    /// tinted modes. Older systems get equivalent manual padding.
    @ViewBuilder
    func widgetContainerBackground<Background: View>(
        isAccessory: Bool,
        @ViewBuilder background: () -> Background
    ) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            if isAccessory {
                containerBackground(for: .widget) { Color.clear }
            } else {
                containerBackground(for: .widget, content: background)
            }
        } else if isAccessory {
            self
        } else {
            padding().background(background())
        }
    }

    @ViewBuilder
    func widgetAccentableIfAvailable() -> some View {
        if #available(iOSApplicationExtension 16.0, *) {
            widgetAccentable()
        } else {
            self
        }
    }
}
