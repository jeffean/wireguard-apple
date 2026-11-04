// SPDX-License-Identifier: MIT
// Copyright © 2018-2026 WireGuard LLC. All Rights Reserved.

import Darwin
import Foundation

protocol TunnelWidgetTransitionClock {
    func now() -> TunnelWidgetTransitionOrder?
}

protocol WidgetBootSessionProvider {
    func identifier() -> String?
}

struct DarwinBootSessionProvider: WidgetBootSessionProvider {
    func identifier() -> String? {
        var requiredSize = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &requiredSize, nil, 0) == 0,
              requiredSize > 1
        else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: requiredSize + 1)
        var actualSize = requiredSize
        let result = buffer.withUnsafeMutableBytes { rawBuffer in
            sysctlbyname(
                "kern.bootsessionuuid",
                rawBuffer.baseAddress,
                &actualSize,
                nil,
                0
            )
        }
        guard result == 0, actualSize > 0, actualSize <= requiredSize else {
            return nil
        }
        return buffer.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else {
                return nil
            }
            return String(validatingCString: baseAddress)
        }
    }
}

struct TunnelWidgetSystemTransitionClock: TunnelWidgetTransitionClock {
    private let bootSessionIdentifier: String?

    init(
        bootSessionIdentifierProvider: WidgetBootSessionProvider =
            DarwinBootSessionProvider()
    ) {
        bootSessionIdentifier = bootSessionIdentifierProvider.identifier()
    }

    func now() -> TunnelWidgetTransitionOrder? {
        bootSessionIdentifier.map {
            TunnelWidgetTransitionOrder(
                bootSessionIdentifier: $0,
                monotonicTimestamp: ProcessInfo.processInfo.systemUptime
            )
        }
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
               proposedOrder.monotonicTimestamp <= existingOrder.monotonicTimestamp {
                return
            }

            let contentChanged =
                existingSnapshot?.status != snapshot.status
                    || existingSnapshot?.tunnelName != snapshot.tunnelName
                    || existingSnapshot?.route != snapshot.route
            let snapshotToPersist: TunnelWidgetSnapshot
            if contentChanged {
                snapshotToPersist = snapshot
            } else if let existingSnapshot {
                snapshotToPersist = TunnelWidgetSnapshot(
                    status: existingSnapshot.status,
                    tunnelName: existingSnapshot.tunnelName,
                    route: existingSnapshot.route,
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
        route: TunnelWidgetRouteSummary? = nil,
        now: Date = Date()
    ) -> Bool {
        let saveResult = backend.save(
            TunnelWidgetSnapshot(
                status: status,
                tunnelName: tunnelName,
                route: route,
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
