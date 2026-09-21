import Foundation

/// Transcription status of recorded audio.
public enum TranscriptionStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case recording
    case queuedOffline
    case transcribingLocal
    case transcribingCloud
    case waitingForCapability
    case paused
    case completed
    case failed
}

/// Metadata describing a local audio lecture recording.
public struct AudioRecordingMetadata: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID
    public var localRelativePath: String
    public var durationSeconds: Double
    public var fileSizeByte: Int64
    public var sampleRate: Double
    public var audioFormat: String
    public var transcriptionStatus: TranscriptionStatus
    public var lastProcessedAudioTime: Double
    public var transcriptionProgress: Double
    public var provider: String?
    public var lastError: String?
    public var retryCount: Int
    public var recordedAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        lectureSessionId: UUID,
        localRelativePath: String = "",
        durationSeconds: Double = 0.0,
        fileSizeByte: Int64 = 0,
        sampleRate: Double = 44100.0,
        audioFormat: String = "m4a",
        transcriptionStatus: TranscriptionStatus = .notStarted,
        lastProcessedAudioTime: Double = 0.0,
        transcriptionProgress: Double = 0.0,
        provider: String? = nil,
        lastError: String? = nil,
        retryCount: Int = 0,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.localRelativePath = localRelativePath
        self.durationSeconds = durationSeconds
        self.fileSizeByte = fileSizeByte
        self.sampleRate = sampleRate
        self.audioFormat = audioFormat
        self.transcriptionStatus = transcriptionStatus
        self.lastProcessedAudioTime = lastProcessedAudioTime
        self.transcriptionProgress = transcriptionProgress
        self.provider = provider
        self.lastError = lastError
        self.retryCount = retryCount
        self.recordedAt = recordedAt
    }
}
