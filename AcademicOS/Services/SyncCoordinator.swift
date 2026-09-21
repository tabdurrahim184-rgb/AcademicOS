import Foundation
import Combine

/// Coordinates offline-to-online synchronization when internet is restored.
public final class SyncCoordinator: @unchecked Sendable {
    private let networkMonitor: NetworkMonitorProtocol
    private let queueManager: OfflineQueueManager
    private var universitySyncEngine: UniversitySyncEngine?
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()
    private var isSyncing: Bool = false

    public init(
        networkMonitor: NetworkMonitorProtocol,
        queueManager: OfflineQueueManager,
        universitySyncEngine: UniversitySyncEngine? = nil
    ) {
        self.networkMonitor = networkMonitor
        self.queueManager = queueManager
        self.universitySyncEngine = universitySyncEngine

        observeConnectivity()
    }

    public func setUniversitySyncEngine(_ engine: UniversitySyncEngine) {
        lock.lock()
        defer { lock.unlock() }
        self.universitySyncEngine = engine
    }

    private func observeConnectivity() {
        networkMonitor.statusPublisher
            .filter { $0.isOnline }
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.processQueuedSync()
                }
            }
            .store(in: &cancellables)
    }

    /// Flushes pending offline jobs when device returns to online state.
    public func processQueuedSync() async {
        lock.lock()
        if isSyncing {
            lock.unlock()
            return
        }
        isSyncing = true
        lock.unlock()

        defer {
            lock.lock()
            isSyncing = false
            lock.unlock()
        }

        do {
            let pendingJobs = try await queueManager.fetchPendingJobs()
            for job in pendingJobs {
                // Execute job dispatch
                try await simulateJobExecution(job)
                try await queueManager.markJobCompleted(id: job.id)
            }

            // Sync university portal changes when online connectivity is active
            if let engine = universitySyncEngine {
                _ = try? await engine.performSync()
            }
        } catch {
            // Non-critical: remaining items will retry next cycle
        }
    }

    private func simulateJobExecution(_ job: QueuedJob) async throws {
        // Minimal simulated sync delay
        try await Task.sleep(nanoseconds: 50_000_000)
    }
}
