// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

enum TunnelWidgetStatus: String, Codable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

struct TunnelWidgetTransitionOrder: Codable, Equatable {
    let bootSessionIdentifier: String
    let monotonicTimestamp: TimeInterval
}

struct TunnelWidgetSnapshot: Codable, Equatable {
    let status: TunnelWidgetStatus
    let tunnelName: String?
    let route: TunnelWidgetRouteSummary?
    let updatedAt: Date
    let transitionOrder: TunnelWidgetTransitionOrder?

    init(
        status: TunnelWidgetStatus,
        tunnelName: String?,
        route: TunnelWidgetRouteSummary? = nil,
        updatedAt: Date,
        transitionOrder: TunnelWidgetTransitionOrder? = nil
    ) {
        self.status = status
        self.tunnelName = tunnelName
        self.route = route
        self.updatedAt = updatedAt
        self.transitionOrder = transitionOrder
    }

    static let disconnected = TunnelWidgetSnapshot(
        status: .disconnected,
        tunnelName: nil,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

enum TunnelWidgetRouteMode: String, Codable {
    /// Every IPv4 destination goes through the tunnel.
    case allTraffic
    /// Every public IPv4 destination goes through the tunnel, private and
    /// local networks do not.
    case allTrafficExcludingLAN
    /// Only some destinations go through the tunnel.
    case split

    /// Whether the tunnel carries all internet traffic, with or without the
    /// local network excluded.
    var coversAllTraffic: Bool {
        switch self {
        case .allTraffic, .allTrafficExcludingLAN:
            return true
        case .split:
            return false
        }
    }
}

/// A display summary of where a tunnel sends traffic, derived from the
/// tunnel configuration when the tunnel starts.
struct TunnelWidgetRouteSummary: Codable, Equatable {
    let mode: TunnelWidgetRouteMode
    let routesIPv6: Bool
    let firstRoute: String?
    let routeCount: Int
    let endpointHost: String?
    let dnsServers: [String]
}

struct TunnelWidgetPeerRoutes {
    let allowedIPs: [String]
    let endpointHost: String?
}

enum TunnelWidgetRouteSummarizer {
    /// The public IPv4 space, matching the ranges the app writes when the
    /// user turns on "Exclude private IPs".
    static let publicIPv4Ranges = [
        "1.0.0.0/8", "2.0.0.0/8", "3.0.0.0/8", "4.0.0.0/6", "8.0.0.0/7", "11.0.0.0/8",
        "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/3",
        "160.0.0.0/5", "168.0.0.0/6", "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10",
        "172.128.0.0/9", "173.0.0.0/8", "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9",
        "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15",
        "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10", "193.0.0.0/8",
        "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4"
    ]

    static func summarize(peers: [TunnelWidgetPeerRoutes], dnsServers: [String]) -> TunnelWidgetRouteSummary {
        let allRoutes = peers.flatMap(\.allowedIPs)
        let fullRange = IPv4Interval(lower: 0, upper: UInt32.max)
        let publicRanges = publicIPv4Ranges.compactMap(IPv4Interval.init(cidr:))

        func covers(_ routes: [String], _ targets: [IPv4Interval]) -> Bool {
            let merged = IPv4Interval.merge(routes.compactMap(IPv4Interval.init(cidr:)))
            return targets.allSatisfy { target in merged.contains { $0.contains(target) } }
        }

        let mode: TunnelWidgetRouteMode
        if covers(allRoutes, [fullRange]) {
            mode = .allTraffic
        } else if covers(allRoutes, publicRanges) {
            mode = .allTrafficExcludingLAN
        } else {
            mode = .split
        }

        // The exit peer is the one that carries the default route. Split
        // tunnels fall back to the first peer with an endpoint.
        let exitPeer: TunnelWidgetPeerRoutes?
        switch mode {
        case .allTraffic:
            exitPeer = peers.first { covers($0.allowedIPs, [fullRange]) }
        case .allTrafficExcludingLAN:
            exitPeer = peers.first { covers($0.allowedIPs, publicRanges) }
        case .split:
            exitPeer = nil
        }
        let endpointHost = (exitPeer ?? peers.first { $0.endpointHost != nil })?.endpointHost

        let routesIPv6 = allRoutes.contains("::/0")
            || (allRoutes.contains("::/1") && allRoutes.contains("8000::/1"))
        let preferredRoute = allRoutes.first { !$0.contains(":") } ?? allRoutes.first

        return TunnelWidgetRouteSummary(
            mode: mode,
            routesIPv6: routesIPv6,
            firstRoute: mode == .split ? preferredRoute : nil,
            routeCount: allRoutes.count,
            endpointHost: endpointHost,
            dnsServers: dnsServers
        )
    }
}

private struct IPv4Interval {
    let lower: UInt32
    let upper: UInt32

    init(lower: UInt32, upper: UInt32) {
        self.lower = lower
        self.upper = upper
    }

    init?(cidr: String) {
        let parts = cidr.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let prefix = UInt8(parts[1]), prefix <= 32 else {
            return nil
        }
        let octets = parts[0].split(separator: ".", omittingEmptySubsequences: false).compactMap { UInt8($0) }
        guard octets.count == 4 else {
            return nil
        }
        let address = octets.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        let mask: UInt32 = prefix == 0 ? 0 : UInt32.max << (32 - UInt32(prefix))
        lower = address & mask
        upper = lower | ~mask
    }

    func contains(_ other: IPv4Interval) -> Bool {
        lower <= other.lower && other.upper <= upper
    }

    static func merge(_ intervals: [IPv4Interval]) -> [IPv4Interval] {
        var merged: [IPv4Interval] = []
        for interval in intervals.sorted(by: { $0.lower < $1.lower }) {
            if let last = merged.last, last.upper == UInt32.max || interval.lower <= last.upper + 1 {
                merged[merged.count - 1] = IPv4Interval(lower: last.lower, upper: max(last.upper, interval.upper))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}
