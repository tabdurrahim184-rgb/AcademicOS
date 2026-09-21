import Foundation

/// Structured outputs produced by AI agents to prevent unstructured prose corruption.
public struct LectureAnalysisResult: Codable, Sendable, Equatable {
    public let summary: String
    public let keyTopics: [String]
    public let definitions: [DefinitionItem]
    public let assignments: [String]
    public let examHints: [String]
    public let openQuestions: [String]

    public init(
        summary: String,
        keyTopics: [String] = [],
        definitions: [DefinitionItem] = [],
        assignments: [String] = [],
        examHints: [String] = [],
        openQuestions: [String] = []
    ) {
        self.summary = summary
        self.keyTopics = keyTopics
        self.definitions = definitions
        self.assignments = assignments
        self.examHints = examHints
        self.openQuestions = openQuestions
    }
}

public struct DefinitionItem: Codable, Sendable, Equatable {
    public let term: String
    public let definition: String
    public let context: String
    public let timestampSeconds: Double?

    public init(term: String, definition: String, context: String = "", timestampSeconds: Double? = nil) {
        self.term = term
        self.definition = definition
        self.context = context
        self.timestampSeconds = timestampSeconds
    }
}

public struct DefinitionResult: Codable, Sendable, Equatable {
    public let definitions: [DefinitionItem]

    public init(definitions: [DefinitionItem]) {
        self.definitions = definitions
    }
}

public struct ProfessorEmphasisItem: Codable, Sendable, Equatable {
    public let snippet: String
    public let classification: String
    public let timestampSeconds: Double
    public let confidence: Double

    public init(snippet: String, classification: String, timestampSeconds: Double, confidence: Double = 0.95) {
        self.snippet = snippet
        self.classification = classification
        self.timestampSeconds = timestampSeconds
        self.confidence = confidence
    }
}

public struct ProfessorEmphasisResult: Codable, Sendable, Equatable {
    public let items: [ProfessorEmphasisItem]

    public init(items: [ProfessorEmphasisItem]) {
        self.items = items
    }
}

public enum FlashcardProposalStatus: String, Codable, Sendable {
    case pending
    case accepted
    case edited
    case rejected
}

public struct FlashcardProposalItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var frontQuestion: String
    public var backAnswer: String
    public var type: String // definition, concept, comparison, example, trueFalse
    public var sourceReference: String?
    public var status: FlashcardProposalStatus

    public init(
        id: UUID = UUID(),
        frontQuestion: String,
        backAnswer: String,
        type: String = "concept",
        sourceReference: String? = nil,
        status: FlashcardProposalStatus = .pending
    ) {
        self.id = id
        self.frontQuestion = frontQuestion
        self.backAnswer = backAnswer
        self.type = type
        self.sourceReference = sourceReference
        self.status = status
    }
}

public struct FlashcardGenerationResult: Codable, Sendable, Equatable {
    public let cards: [FlashcardProposalItem]

    public init(cards: [FlashcardProposalItem]) {
        self.cards = cards
    }
}

public enum QuizQuestionType: String, Codable, Sendable {
    case multipleChoice
    case shortAnswer
    case trueFalse
    case mixed
}

public struct QuizQuestionItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let questionText: String
    public let options: [String] // Empty for short answer
    public let correctOptionIndex: Int
    public let explanation: String
    public let sourceReference: String?
    public let type: QuizQuestionType

    public init(
        id: UUID = UUID(),
        questionText: String,
        options: [String] = [],
        correctOptionIndex: Int = 0,
        explanation: String,
        sourceReference: String? = nil,
        type: QuizQuestionType = .multipleChoice
    ) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.correctOptionIndex = correctOptionIndex
        self.explanation = explanation
        self.sourceReference = sourceReference
        self.type = type
    }
}

public struct QuizGenerationResult: Codable, Sendable, Equatable {
    public let title: String
    public let questions: [QuizQuestionItem]

    public init(title: String, questions: [QuizQuestionItem]) {
        self.title = title
        self.questions = questions
    }
}

public struct QuizSummaryResult: Codable, Sendable, Equatable {
    public let totalQuestions: Int
    public let correctCount: Int
    public let scorePercentage: Double
    public let weakAreas: [String]
    public let strongAreas: [String]
    public let reviewSuggestions: [String]

    public init(
        totalQuestions: Int,
        correctCount: Int,
        scorePercentage: Double,
        weakAreas: [String],
        strongAreas: [String],
        reviewSuggestions: [String]
    ) {
        self.totalQuestions = totalQuestions
        self.correctCount = correctCount
        self.scorePercentage = scorePercentage
        self.weakAreas = weakAreas
        self.strongAreas = strongAreas
        self.reviewSuggestions = reviewSuggestions
    }
}

public struct StudyPlanItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let topic: String
    public let durationMinutes: Int
    public let activityType: String // e.g. "Concept Review", "Active Recall", "Flashcards", "Quiz"
    public let order: Int

    public init(id: UUID = UUID(), topic: String, durationMinutes: Int, activityType: String, order: Int) {
        self.id = id
        self.topic = topic
        self.durationMinutes = durationMinutes
        self.activityType = activityType
        self.order = order
    }
}

public struct StudyGuideResult: Codable, Sendable, Equatable {
    public let courseName: String
    public let targetExamDate: Date?
    public let totalMinutes: Int
    public let items: [StudyPlanItem]

    public init(courseName: String, targetExamDate: Date?, totalMinutes: Int, items: [StudyPlanItem]) {
        self.courseName = courseName
        self.targetExamDate = targetExamDate
        self.totalMinutes = totalMinutes
        self.items = items
    }
}

/// Validates raw JSON output from AI models before committing to SQLite.
public struct AIOutputValidator: Sendable {
    public static func validateAndDecode<T: Decodable>(_ type: T.Type, from jsonString: String) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw AIProviderError.malformedStructuredResponse("Failed to encode input string to utf8 data.")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AIProviderError.malformedStructuredResponse("Malformed output for \(String(describing: type)): \(error.localizedDescription)")
        }
    }
}
