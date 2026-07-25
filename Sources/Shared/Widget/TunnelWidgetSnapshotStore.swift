// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Darwin
import Foundation

protocol TunnelWidgetTransitionClock {
    func now() -> TunnelWidgetTransitionOrder
}

struct TunnelWidgetSystemTransitionClock: TunnelWidgetTransitionClock {
    private static let bootSessionIdentifier = resolveBootSessionIdentifier()

    func now() -> TunnelWidgetTransitionOrder {
        TunnelWidgetTransitionOrder(
            bootSessionIdentifier: Self.bootSessionIdentifier,
            monotonicTimestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    private static func resolveBootSessionIdentifier() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 {
            return "\(bootTime.tv_sec):\(bootTime.tv_usec)"
        }

        let estimatedBootDate =
            Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        return "estimated:\(Int(estimatedBootDate.rounded()))"
    }
}

enum TunnelWidgetSnapshotSaveResult {
    case contentChanged
    case watermarkAdvanced
    case rejected
}

protocol TunnelWidgetSnapshotBackend {
    func load() -> TunnelWidgetSnapshot?
    func save(_ snapshot: TunnelWidgetSnapshot) -> TunnelWidgetSnapshotSaveResult
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
            snapshot = loadUncoordinated(from: coordinatedURL)
        }
        return snapshot
    }

    func save(_ snapshot: TunnelWidgetSnapshot) -> TunnelWidgetSnapshotSaveResult {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .rejected
        }

        var saveResult = TunnelWidgetSnapshotSaveResult.rejected
        var coordinationError: NSError?
        fileCoordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            let existingSnapshot = loadUncoordinated(from: coordinatedURL)
            if let existingOrder = existingSnapshot?.transitionOrder,
               let proposedOrder = snapshot.transitionOrder,
               existingOrder.bootSessionIdentifier == proposedOrder.bootSessionIdentifier,
               proposedOrder.monotonicTimestamp <= existingOrder.monotonicTimestamp
            {
                return
            }

            let contentChanged =
                existingSnapshot?.status != snapshot.status
                    || existingSnapshot?.tunnelName != snapshot.tunnelName
            let snapshotToPersist: TunnelWidgetSnapshot
            if contentChanged {
                snapshotToPersist = snapshot
            } else if let existingSnapshot {
                snapshotToPersist = TunnelWidgetSnapshot(
                    status: existingSnapshot.status,
                    tunnelName: existingSnapshot.tunnelName,
                    updatedAt: existingSnapshot.updatedAt,
                    transitionOrder: snapshot.transitionOrder
                )
            } else {
                snapshotToPersist = snapshot
            }

            guard let data = try? encoder.encode(snapshotToPersist) else {
                return
            }
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                saveResult = contentChanged ? .contentChanged : .watermarkAdvanced
            } catch {
                return
            }
        }
        return coordinationError == nil ? saveResult : .rejected
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
    private let transitionClock: TunnelWidgetTransitionClock

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
        self.init(backend: backend, transitionClock: TunnelWidgetSystemTransitionClock())
    }

    init(
        backend: TunnelWidgetSnapshotBackend,
        transitionClock: TunnelWidgetTransitionClock = TunnelWidgetSystemTransitionClock()
    ) {
        self.backend = backend
        self.transitionClock = transitionClock
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
        let saveResult = backend.save(
            TunnelWidgetSnapshot(
                status: status,
                tunnelName: tunnelName,
                updatedAt: now,
                transitionOrder: transitionClock.now()
            )
        )
        if case .contentChanged = saveResult {
            return true
        }
        return false
    }
}

private final class TunnelWidgetSnapshotUnavailableBackend: TunnelWidgetSnapshotBackend {
    func load() -> TunnelWidgetSnapshot? {
        nil
    }

    func save(_: TunnelWidgetSnapshot) -> TunnelWidgetSnapshotSaveResult {
        .rejected
    }
}
