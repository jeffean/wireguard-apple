// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

enum TunnelWidgetStatus: String, Codable {
  case disconnected
  case connecting
  case connected
  case disconnecting
}

struct TunnelWidgetSnapshot: Codable, Equatable {
  let status: TunnelWidgetStatus
  let tunnelName: String?
  let updatedAt: Date

  static let disconnected = TunnelWidgetSnapshot(
    status: .disconnected,
    tunnelName: nil,
    updatedAt: Date(timeIntervalSince1970: 0)
  )
}
