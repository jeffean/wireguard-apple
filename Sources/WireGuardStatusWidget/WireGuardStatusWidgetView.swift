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

    private var route: RouteDisplay? {
        snapshot.route.map(RouteDisplay.init(summary:))
    }

    private var isActive: Bool {
        snapshot.status != .disconnected
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

    @ViewBuilder
    private var smallView: some View {
        if isActive {
            VStack(alignment: .leading, spacing: 0) {
                StatusCaption(style: style, connectedSince: connectedSince, timerFont: .caption.weight(.semibold))
                Text(verbatim: tunnelName)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)
                if let route {
                    RoutePill(route: route, style: style, isCompact: true)
                        .padding(.top, 4)
                }
                Spacer(minLength: 4)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array((route?.details ?? []).prefix(2))) { detail in
                        DetailLine(detail: detail)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                StatusBadge(style: style, diameter: 40)
                Spacer(minLength: 8)
                Text("Not connected")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("No active tunnel")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var mediumView: some View {
        if isActive {
            VStack(alignment: .leading, spacing: 0) {
                StatusCaption(
                    style: style,
                    connectedSince: connectedSince,
                    timerFont: .system(.title3, design: .rounded).weight(.semibold)
                )
                HStack(spacing: 8) {
                    Text(verbatim: tunnelName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let route {
                        RoutePill(route: route, style: style, isCompact: false)
                            .fixedSize()
                    }
                }
                Spacer(minLength: 6)
                detailGrid
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 14) {
                StatusBadge(style: style, diameter: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WireGuard")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("Not connected")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("No active tunnel")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var detailGrid: some View {
        let details = Array((route?.details ?? []).prefix(4))
        let leading = details.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        let trailing = details.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(leading) { DetailLine(detail: $0, font: .footnote.weight(.medium)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(trailing) { DetailLine(detail: $0, font: .footnote.weight(.medium)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                if isActive {
                    Text(verbatim: tunnelName)
                } else {
                    Text("Not connected")
                }
            } icon: {
                Image(systemName: style.symbolName)
            }
            .font(.headline)
            .lineLimit(1)
            .widgetAccentable()
            if isActive, let route {
                (Text(route.shortTitle) + Text(verbatim: " · ") + route.dnsText)
                    .font(.subheadline)
                    .lineLimit(1)
                    .privacySensitive()
            }
            if let connectedSince {
                Text(connectedSince, style: .timer)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            } else {
                Text(isActive ? style.title : "No active tunnel")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @available(iOSApplicationExtension 16.0, *)
    private var inlineView: some View {
        Label {
            if !isActive {
                Text("Not connected")
            } else if let route {
                Text(verbatim: tunnelName) + Text(verbatim: " · ") + Text(route.shortTitle)
            } else {
                Text(verbatim: tunnelName) + Text(verbatim: " · ") + Text(style.title)
            }
        } icon: {
            Image(systemName: style.symbolName)
        }
    }

    // MARK: - Shared Pieces

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

/// Display strings and detail rows for a route summary.
struct RouteDisplay {
    struct Detail: Identifiable {
        let id: String
        let symbolName: String
        let text: Text
        let isWarning: Bool
    }

    let shortTitle: LocalizedStringKey
    let longTitle: Text
    let symbolName: String
    let dnsText: Text
    let details: [Detail]

    init(summary: TunnelWidgetRouteSummary) {
        let dnsText: Text
        if let firstServer = summary.dnsServers.first {
            let extraCount = summary.dnsServers.count - 1
            dnsText = extraCount > 0
                ? Text("DNS \(firstServer) +\(extraCount)")
                : Text("DNS \(firstServer)")
        } else {
            dnsText = Text("System DNS")
        }
        self.dnsText = dnsText

        let endpoint = summary.endpointHost.map {
            Detail(id: "endpoint", symbolName: "server.rack", text: Text(verbatim: $0), isWarning: false)
        }
        let dns = Detail(id: "dns", symbolName: "text.magnifyingglass", text: dnsText, isWarning: false)
        let ipv6 = summary.routesIPv6
            ? Detail(id: "ipv6", symbolName: "checkmark.shield", text: Text("IPv4 + IPv6"), isWarning: false)
            : Detail(id: "ipv6", symbolName: "exclamationmark.triangle", text: Text("IPv6 not tunneled"), isWarning: true)

        switch summary.mode {
        case .allTraffic:
            shortTitle = "All traffic"
            longTitle = Text("All traffic")
            symbolName = "globe"
            details = [endpoint, dns, ipv6].compactMap { $0 }
        case .allTrafficExcludingLAN:
            shortTitle = "All traffic"
            longTitle = Text("All traffic")
            symbolName = "globe"
            let lan = Detail(id: "lan", symbolName: "house", text: Text("LAN excluded"), isWarning: false)
            details = [endpoint, dns, lan, ipv6].compactMap { $0 }
        case .split:
            shortTitle = "Split"
            longTitle = summary.routeCount == 1
                ? Text("Split · 1 route")
                : Text("Split · \(summary.routeCount) routes")
            symbolName = "arrow.triangle.branch"
            let extraRoutes = summary.routeCount - 1
            let routeText: Text? = summary.firstRoute.map { firstRoute in
                extraRoutes > 0 ? Text(verbatim: "\(firstRoute) +\(extraRoutes)") : Text(verbatim: firstRoute)
            }
            let routes = routeText.map {
                Detail(id: "routes", symbolName: "arrow.triangle.branch", text: $0, isWarning: false)
            }
            let internet = Detail(id: "internet", symbolName: "globe", text: Text("Internet direct"), isWarning: false)
            details = [routes, dns, endpoint, internet].compactMap { $0 }
        }
    }
}

struct StatusCaption: View {
    let style: StatusStyle
    let connectedSince: Date?
    let timerFont: Font

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Circle()
                .fill(style.tint)
                .frame(width: 7, height: 7)
            Text(style.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(style.tint)
                .lineLimit(1)
                .fixedSize()
            if let connectedSince {
                // WidgetKit reports a timer's ideal width as unbounded, so it
                // fills the remaining width and aligns itself to the trailing edge.
                Text(connectedSince, style: .timer)
                    .font(timerFont)
                    .monospacedDigit()
                    .foregroundColor(style.tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
        }
        .widgetAccentableIfAvailable()
    }
}

struct RoutePill: View {
    let route: RouteDisplay
    let style: StatusStyle
    let isCompact: Bool

    var body: some View {
        Label {
            if isCompact {
                Text(route.shortTitle)
            } else {
                route.longTitle
            }
        } icon: {
            Image(systemName: route.symbolName)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .foregroundColor(style.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(style.tint.opacity(0.16)))
    }
}

struct DetailLine: View {
    let detail: RouteDisplay.Detail
    var font: Font = .caption.weight(.medium)

    var body: some View {
        Label {
            detail.text
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: detail.symbolName)
                .foregroundColor(detail.isWarning ? .orange : .secondary)
        }
        .font(font)
        .foregroundColor(detail.isWarning ? .orange : .secondary)
        .privacySensitive()
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
