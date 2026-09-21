import Foundation
import SwiftUI

/// Certainty classification of professor statements and AI recommendations.
public enum ProfessorEmphasisClassification: String, Codable, Sendable, CaseIterable {
    case explicitExamHint = "EXPLICIT_EXAM_HINT"
    case professorEmphasis = "PROFESSOR_EMPHASIS"
    case importantDefinition = "IMPORTANT_DEFINITION"
    case importantExample = "IMPORTANT_EXAMPLE"
    case assignmentInstruction = "ASSIGNMENT_INSTRUCTION"
    case reviewRecommendation = "REVIEW_RECOMMENDATION"

    public var title: String {
        switch self {
        case .explicitExamHint:
            return "PROFESSOR EXPLICITLY MENTIONED EXAM"
        case .professorEmphasis:
            return "PROFESSOR STRONGLY EMPHASIZED"
        case .importantDefinition:
            return "CRITICAL DEFINITION"
        case .importantExample:
            return "HIGH-YIELD EXAMPLE"
        case .assignmentInstruction:
            return "ASSIGNMENT INSTRUCTION"
        case .reviewRecommendation:
            return "AI RECOMMENDS REVIEWING"
        }
    }

    /// Color code enforcing Section 13 Truth Standards:
    /// RED = Explicit exam mention, ORANGE = Strong professor emphasis, BLUE = AI recommendation.
    public var accentColor: Color {
        switch self {
        case .explicitExamHint:
            return Color.academicCrimson
        case .professorEmphasis, .importantDefinition, .assignmentInstruction:
            return Color.academicAmber
        case .importantExample:
            return Color.academicEmerald
        case .reviewRecommendation:
            return Color.academicCyan
        }
    }
}

/// How the emphasis was detected in the transcript.
public enum EmphasisDetectionMethod: String, Codable, Sendable {
    case explicitPhrase = "explicitPhrase"
    case audioMarker = "audioMarker"
    case repetitionContext = "repetitionContext"
    case aiContext = "aiContext"
    case hybrid = "hybrid"
}

/// A detected high-yield academic statement with full source traceability.
public struct ProfessorEmphasis: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let courseId: UUID
    public let lectureSessionId: UUID?
    public let recordingId: UUID
    public let transcriptSegmentId: UUID?
    public let startTime: Double
    public let endTime: Double
    public let exactSourceSnippet: String
    public let classification: ProfessorEmphasisClassification
    public let confidence: Double
    public let detectionMethod: EmphasisDetectionMethod
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        recordingId: UUID,
        transcriptSegmentId: UUID? = nil,
        startTime: Double,
        endTime: Double,
        exactSourceSnippet: String,
        classification: ProfessorEmphasisClassification,
        confidence: Double = 0.95,
        detectionMethod: EmphasisDetectionMethod = .explicitPhrase,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.recordingId = recordingId
        self.transcriptSegmentId = transcriptSegmentId
        self.startTime = startTime
        self.endTime = endTime
        self.exactSourceSnippet = exactSourceSnippet
        self.classification = classification
        self.confidence = confidence
        self.detectionMethod = detectionMethod
        self.createdAt = createdAt
    }

    public var formattedTimestamp: String {
        let total = Int(startTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
