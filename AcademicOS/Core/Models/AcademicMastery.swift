import Foundation

/// Local deterministic mastery record for course topics.
/// Calculated purely by student quiz and flashcard performance, never invented by AI.
public struct AcademicMastery: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let courseId: UUID
    public var topic: String
    public var attempts: Int
    public var correctAnswers: Int
    public var incorrectAnswers: Int
    public var confidence: Double // 0.0 to 1.0
    public var lastReviewed: Date
    public var masteryScore: Double // 0.0 to 1.0

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        topic: String,
        attempts: Int = 0,
        correctAnswers: Int = 0,
        incorrectAnswers: Int = 0,
        confidence: Double = 0.5,
        lastReviewed: Date = Date(),
        masteryScore: Double = 0.0
    ) {
        self.id = id
        self.courseId = courseId
        self.topic = topic
        self.attempts = attempts
        self.correctAnswers = correctAnswers
        self.incorrectAnswers = incorrectAnswers
        self.confidence = confidence
        self.lastReviewed = lastReviewed
        self.masteryScore = masteryScore
    }

    /// Deterministically recalibrates mastery score based on real student performance.
    public mutating func recordAttempt(isCorrect: Bool, userConfidence: Double = 0.5) {
        self.attempts += 1
        if isCorrect {
            self.correctAnswers += 1
        } else {
            self.incorrectAnswers += 1
        }
        self.confidence = max(0.0, min(1.0, userConfidence))
        self.lastReviewed = Date()

        let accuracyRatio = Double(correctAnswers) / Double(max(1, attempts))
        // 80% accuracy weight, 20% confidence weight
        self.masteryScore = max(0.0, min(1.0, (accuracyRatio * 0.8) + (self.confidence * 0.2)))
    }
}
