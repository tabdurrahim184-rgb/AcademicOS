import Foundation

/// Status of an offline queued operation.
public enum JobStatus: String, Codable, Sendable, CaseIterable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

/// A network-dependent operation safely persisted locally while offline.
public struct QueuedJob: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var jobType: String // e.g., "gemini_transcription", "lms_sync", "cloud_backup"
    public var payloadJson: String
    public var status: JobStatus
    public var priority: Int // 0 is highest
    public var retryCount: Int
    public var maxRetries: Int
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        jobType: String,
        payloadJson: String,
        status: JobStatus = .pending,
        priority: Int = 1,
        retryCount: Int = 0,
        maxRetries: Int = 5,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.jobType = jobType
        self.payloadJson = payloadJson
        self.status = status
        self.priority = priority
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.errorMessage = errorMessage
    }
}
