// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Foundation

protocol TunnelWidgetSnapshotBackend {
    func load() -> TunnelWidgetSnapshot?

    @discardableResult
    func saveIfChanged(_ snapshot: TunnelWidgetSnapshot) -> Bool
}

final class TunnelWidgetSnapshotFileBackend: TunnelWidgetSnapshotBackend {
    private let fileURL: URL
    private let fileCoordinator: NSFileCoordinator
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileURL: URL,
        fileCoordinator: NSFileCoordinator = NSFileCoordinator(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileCoordinator = fileCoordinator
        self.fileManager = fileManager
    }

    func load() -> TunnelWidgetSnapshot? {
        var snapshot: TunnelWidgetSnapshot?
        var coordinationError: NSError?
        fileCoordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            guard let data = try? Data(contentsOf: coordinatedURL) else {
                return
            }
            snapshot = try? decoder.decode(TunnelWidgetSnapshot.self, from: data)
        }
        return snapshot
    }

    @discardableResult
    func saveIfChanged(_ snapshot: TunnelWidgetSnapshot) -> Bool {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return false
        }

        var didSave = false
        var coordinationError: NSError?
        fileCoordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            let existingSnapshot = loadUncoordinated(from: coordinatedURL)
            if let existingSnapshot {
                guard existingSnapshot.status != snapshot.status
                    || existingSnapshot.tunnelName != snapshot.tunnelName
                else {
                    return
                }
                guard snapshot.updatedAt > existingSnapshot.updatedAt else {
                    return
                }
            }

            guard let data = try? encoder.encode(snapshot) else {
                return
            }
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                didSave = true
            } catch {
                return
            }
        }
        return coordinationError == nil && didSave
    }

    private func loadUncoordinated(from url: URL) -> TunnelWidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(TunnelWidgetSnapshot.self, from: data)
    }
}

final class TunnelWidgetSnapshotStore {
    static let fileName = "TunnelWidgetSnapshot.json"

    private static let appGroupIdentifierKey = "AppGroupIdentifier"

    private let backend: TunnelWidgetSnapshotBackend

    convenience init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        let appGroupIdentifier =
            bundle.object(forInfoDictionaryKey: Self.appGroupIdentifierKey) as? String
        let fileURL = appGroupIdentifier
            .flatMap { fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            .map { $0.appendingPathComponent(Self.fileName) }
        let backend: TunnelWidgetSnapshotBackend
        if let fileURL {
            backend = TunnelWidgetSnapshotFileBackend(fileURL: fileURL, fileManager: fileManager)
        } else {
            backend = TunnelWidgetSnapshotUnavailableBackend()
        }
        self.init(backend: backend)
    }

    init(backend: TunnelWidgetSnapshotBackend) {
        self.backend = backend
    }

    func load() -> TunnelWidgetSnapshot {
        backend.load() ?? .disconnected
    }

    @discardableResult
    func saveIfChanged(
        status: TunnelWidgetStatus,
        tunnelName: String?,
        now: Date = Date()
    ) -> Bool {
        backend.saveIfChanged(
            TunnelWidgetSnapshot(status: status, tunnelName: tunnelName, updatedAt: now)
        )
    }
}

private final class TunnelWidgetSnapshotUnavailableBackend: TunnelWidgetSnapshotBackend {
    func load() -> TunnelWidgetSnapshot? {
        nil
    }

    func saveIfChanged(_: TunnelWidgetSnapshot) -> Bool {
        false
    }
}
