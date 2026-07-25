// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

final class TunnelWidgetSnapshotStore {
  static let storageKey = "TunnelWidgetSnapshot.v1"

  private static let appGroupIdentifierKey = "AppGroupIdentifier"

  private let userDefaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  convenience init(bundle: Bundle = .main) {
    let suiteName = bundle.object(forInfoDictionaryKey: Self.appGroupIdentifierKey) as? String
    let userDefaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    self.init(userDefaults: userDefaults)
  }

  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  func load() -> TunnelWidgetSnapshot {
    loadStoredSnapshot() ?? .disconnected
  }

  @discardableResult
  func saveIfChanged(status: TunnelWidgetStatus, tunnelName: String?, now: Date = Date()) -> Bool {
    if let existingSnapshot = loadStoredSnapshot(),
      existingSnapshot.status == status,
      existingSnapshot.tunnelName == tunnelName
    {
      return false
    }

    let snapshot = TunnelWidgetSnapshot(status: status, tunnelName: tunnelName, updatedAt: now)
    guard let data = try? encoder.encode(snapshot) else {
      return false
    }
    userDefaults.set(data, forKey: Self.storageKey)
    return true
  }

  private func loadStoredSnapshot() -> TunnelWidgetSnapshot? {
    guard let data = userDefaults.data(forKey: Self.storageKey) else {
      return nil
    }
    return try? decoder.decode(TunnelWidgetSnapshot.self, from: data)
  }
}
