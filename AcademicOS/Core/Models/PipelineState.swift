import Foundation

/// Progress stages in the end-to-end Lecture Intelligence Pipeline.
public enum PipelineStage: String, Codable, Sendable, CaseIterable {
    case recorded = "recorded"
    case transcribing = "transcribing"
    case transcribed = "transcribed"
    case analyzing = "analyzing"
    case notesGenerated = "notesGenerated"
    case studyMaterialsGenerated = "studyMaterialsGenerated"
    case completed = "completed"
    case failedRecoverable = "failedRecoverable"
    case failedPermanent = "failedPermanent"

    public var title: String {
        switch self {
        case .recorded: return "Audio Stored"
        case .transcribing: return "Speech-to-Text"
        case .transcribed: return "Transcribed"
        case .analyzing: return "Academic Analysis"
        case .notesGenerated: return "Notes Synthesized"
        case .studyMaterialsGenerated: return "Study Materials Ready"
        case .completed: return "Pipeline Complete"
        case .failedRecoverable: return "Paused / Retryable"
        case .failedPermanent: return "Permanent Error"
        }
    }

    public var isTerminal: Bool {
        return self == .completed || self == .failedPermanent
    }
}

/// Persistent record tracking the execution state of a lecture's AI analysis pipeline.
public struct LecturePipelineRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let recordingId: UUID
    public let courseId: UUID
    public let lectureSessionId: UUID?
    public var currentStage: PipelineStage
    public var progressPercentage: Double
    public var lastProcessedChunk: Int
    public var totalChunks: Int
    public var lastError: String?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingId: UUID,
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        currentStage: PipelineStage = .recorded,
        progressPercentage: Double = 0.0,
        lastProcessedChunk: Int = 0,
        totalChunks: Int = 0,
        lastError: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordingId = recordingId
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.currentStage = currentStage
        self.progressPercentage = progressPercentage
        self.lastProcessedChunk = lastProcessedChunk
        self.totalChunks = totalChunks
        self.lastError = lastError
        self.updatedAt = updatedAt
    }
}
