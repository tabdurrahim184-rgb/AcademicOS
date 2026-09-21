import Foundation

/// Manages offline-first operations by queuing network tasks locally.
public actor OfflineQueueManager {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    /// Enqueues a network dependent job when offline or connection is limited.
    public func enqueueJob(type: String, payload: Encodable, priority: Int = 1) async throws -> QueuedJob {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        let job = QueuedJob(
            jobType: type,
            payloadJson: payloadString,
            status: .pending,
            priority: priority
        )

        try await localStore.save(job)
        return job
    }

    /// Fetches all pending jobs sorted by priority (0 first) and creation date.
    public func fetchPendingJobs() async throws -> [QueuedJob] {
        let allJobs: [QueuedJob] = try await localStore.fetchAll()
        return allJobs
            .filter { $0.status == .pending || $0.status == .failed && $0.retryCount < $0.maxRetries }
            .sorted { ($0.priority, $0.createdAt) < ($1.priority, $1.createdAt) }
    }

    /// Marks a job as completed and deletes or updates it.
    public func markJobCompleted(id: UUID) async throws {
        if var job: QueuedJob = try await localStore.fetch(id: id) {
            job.status = .completed
            try await localStore.save(job)
        }
    }

    /// Records a failed attempt for a job.
    public func recordJobFailure(id: UUID, error: Error) async throws {
        if var job: QueuedJob = try await localStore.fetch(id: id) {
            job.retryCount += 1
            job.lastAttemptAt = Date()
            job.errorMessage = error.localizedDescription
            if job.retryCount >= job.maxRetries {
                job.status = .failed
            }
            try await localStore.save(job)
        }
    }

    /// Count of pending jobs
    public func pendingJobsCount() async throws -> Int {
        let pending = try await fetchPendingJobs()
        return pending.count
    }
}
