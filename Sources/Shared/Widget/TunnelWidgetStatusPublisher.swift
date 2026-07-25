// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

#if os(iOS)
    import WidgetKit
#endif

struct TunnelWidgetStatusCandidate {
    enum State {
        case inactive
        case activating
        case active
        case deactivating
        case reasserting
        case restarting
        case waiting
    }

    let state: State
    let tunnelName: String
}

struct TunnelWidgetResolvedStatus: Equatable {
    let status: TunnelWidgetStatus
    let tunnelName: String?
}

enum TunnelWidgetStatusResolver {
    static func resolve(_ candidates: [TunnelWidgetStatusCandidate]) -> TunnelWidgetResolvedStatus {
        if let active = candidates.first(where: { $0.state == .active }) {
            return TunnelWidgetResolvedStatus(status: .connected, tunnelName: active.tunnelName)
        }

        if let deactivating = candidates.first(where: { $0.state == .deactivating }) {
            return TunnelWidgetResolvedStatus(status: .disconnecting, tunnelName: deactivating.tunnelName)
        }

        if let connecting = candidates.first(where: {
            switch $0.state {
            case .activating, .reasserting, .restarting, .waiting:
                return true
            case .inactive, .active, .deactivating:
                return false
            }
        }) {
            return TunnelWidgetResolvedStatus(status: .connecting, tunnelName: connecting.tunnelName)
        }

        return TunnelWidgetResolvedStatus(status: .disconnected, tunnelName: nil)
    }
}

#if os(iOS)
    enum TunnelWidgetStatusPublisher {
        static let widgetKind = "TunnelStatusWidget"

        static func publish(status: TunnelWidgetStatus, tunnelName: String?) {
            let invocationDate = Date()
            let store = TunnelWidgetSnapshotStore()
            guard store.saveIfChanged(
                status: status,
                tunnelName: tunnelName,
                now: invocationDate
            ) else {
                return
            }
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }
#endif
