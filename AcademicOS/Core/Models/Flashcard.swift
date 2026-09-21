import Foundation

/// Represents a study flashcard utilizing spaced-repetition parameters.
public struct Flashcard: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var deckTitle: String
    public var question: String
    public var answer: String
    public var difficulty: Int // 1 to 5
    public var reviewCount: Int
    public var nextReviewDate: Date
    public var easeFactor: Double
    public var intervalDays: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        deckTitle: String = "General Core",
        question: String,
        answer: String,
        difficulty: Int = 3,
        reviewCount: Int = 0,
        nextReviewDate: Date = Date(),
        easeFactor: Double = 2.5,
        intervalDays: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.deckTitle = deckTitle
        self.question = question
        self.answer = answer
        self.difficulty = difficulty
        self.reviewCount = reviewCount
        self.nextReviewDate = nextReviewDate
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.createdAt = createdAt
    }
}
