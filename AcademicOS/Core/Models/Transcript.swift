import Foundation

/// A timestamped slice of speech transcription.
public struct TranscriptSegment: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var recordingId: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID?
    public var startSeconds: Double
    public var endSeconds: Double
    public var speakerTag: String?
    public var text: String
    public var confidence: Double
    public var isMarkedImportant: Bool
    public var importanceTag: String?

    public init(
        id: UUID = UUID(),
        recordingId: UUID,
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        startSeconds: Double,
        endSeconds: Double,
        speakerTag: String? = nil,
        text: String,
        confidence: Double = 0.95,
        isMarkedImportant: Bool = false,
        importanceTag: String? = nil
    ) {
        self.id = id
        self.recordingId = recordingId
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.speakerTag = speakerTag
        self.text = text
        self.confidence = confidence
        self.isMarkedImportant = isMarkedImportant
        self.importanceTag = importanceTag
    }

    public var formattedTimestamp: String {
        let total = Int(startSeconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

/// Full speech transcription corresponding to a recorded audio session.
public struct Transcript: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var recordingId: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID?
    public var fullText: String
    public var segments: [TranscriptSegment]
    public var language: String
    public var isProcessedByAI: Bool
    public var generatedAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingId: UUID,
        courseId: UUID = UUID(),
        lectureSessionId: UUID? = nil,
        fullText: String,
        segments: [TranscriptSegment] = [],
        language: String = "tr-TR",
        isProcessedByAI: Bool = false,
        generatedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordingId = recordingId
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.fullText = fullText
        self.segments = segments
        self.language = language
        self.isProcessedByAI = isProcessedByAI
        self.generatedAt = generatedAt
        self.updatedAt = updatedAt
    }
}
