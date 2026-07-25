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
    let updatedAt: Date
    let transitionOrder: TunnelWidgetTransitionOrder?

    init(
        status: TunnelWidgetStatus,
        tunnelName: String?,
        updatedAt: Date,
        transitionOrder: TunnelWidgetTransitionOrder? = nil
    ) {
        self.status = status
        self.tunnelName = tunnelName
        self.updatedAt = updatedAt
        self.transitionOrder = transitionOrder
    }

    static let disconnected = TunnelWidgetSnapshot(
        status: .disconnected,
        tunnelName: nil,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
