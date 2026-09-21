import Foundation

/// Specific task categories executed by the AI subsystem.
public enum AITaskType: String, Codable, Sendable, CaseIterable {
    case summarizeLecture
    case structureLectureNotes
    case detectProfessorEmphasis
    case extractDefinitions
    case extractAssignments
    case generateFlashcards
    case generateQuiz
    case generateExamReview
    case answerCourseQuestion
    case explainConcept
    case createStudyPlan
    case compareConcepts
    case academicCommanderRequest

    public var displayName: String {
        switch self {
        case .summarizeLecture: return "Lecture Summary"
        case .structureLectureNotes: return "Structured Notes"
        case .detectProfessorEmphasis: return "Professor Emphasis"
        case .extractDefinitions: return "Definition Extraction"
        case .extractAssignments: return "Assignment Extraction"
        case .generateFlashcards: return "Flashcard Generation"
        case .generateQuiz: return "Quiz Generation"
        case .generateExamReview: return "Exam Review Sheet"
        case .answerCourseQuestion: return "Course Question"
        case .explainConcept: return "Concept Explanation"
        case .createStudyPlan: return "Study Plan"
        case .compareConcepts: return "Concept Comparison"
        case .academicCommanderRequest: return "Commander Briefing"
        }
    }
}

/// Structured representation of an academic AI task submitted to AIRouter.
public struct AITask: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let type: AITaskType
    public let courseId: UUID?
    public let lectureSessionId: UUID?
    public let inputReferences: [String: String]
    public let privacyLevel: AIPrivacyLevel
    public let preferredProvider: AIProviderType?
    public let requiresInternet: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        type: AITaskType,
        courseId: UUID? = nil,
        lectureSessionId: UUID? = nil,
        inputReferences: [String: String] = [:],
        privacyLevel: AIPrivacyLevel = .cloudAllowed,
        preferredProvider: AIProviderType? = nil,
        requiresInternet: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.inputReferences = inputReferences
        self.privacyLevel = privacyLevel
        self.preferredProvider = preferredProvider
        self.requiresInternet = requiresInternet
        self.createdAt = createdAt
    }
}
