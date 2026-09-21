import Foundation

/// Classification of academic facts and context preserved in course-specific AI memory.
public enum AIMemoryType: String, Codable, Sendable, CaseIterable {
    case concept = "concept"
    case definition = "definition"
    case professorEmphasis = "professorEmphasis"
    case examHint = "examHint"
    case assignmentInstruction = "assignmentInstruction"
    case importantFact = "importantFact"
    case studentWeakness = "studentWeakness"
    case studentStrength = "studentStrength"
    case courseRule = "courseRule"
    case manualMemory = "manualMemory"

    public var title: String {
        switch self {
        case .concept: return "Concept"
        case .definition: return "Definition"
        case .professorEmphasis: return "Professor Emphasis"
        case .examHint: return "Exam Hint"
        case .assignmentInstruction: return "Assignment Instruction"
        case .importantFact: return "Important Fact"
        case .studentWeakness: return "Needs Review"
        case .studentStrength: return "Mastered Topic"
        case .courseRule: return "Course Rule"
        case .manualMemory: return "Student Pin"
        }
    }
}

/// Represents a distinct piece of contextual knowledge remembered by the course/student AI.
public struct AIMemoryEntry: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID?
    public var topic: String
    public var content: String
    public var type: AIMemoryType
    public var importanceScore: Double // 0.0 to 1.0
    public var sourceReference: String
    public var tags: [String]
    public var isUserVerified: Bool
    public var isPinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        topic: String,
        content: String,
        type: AIMemoryType = .concept,
        importanceScore: Double = 0.8,
        sourceReference: String = "Course Notes",
        tags: [String] = [],
        isUserVerified: Bool = false,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.topic = topic
        self.content = content
        self.type = type
        self.importanceScore = importanceScore
        self.sourceReference = sourceReference
        self.tags = tags
        self.isUserVerified = isUserVerified
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Legacy compatibility property
    public var keyFact: String {
        get { content }
        set { content = newValue }
    }
}
