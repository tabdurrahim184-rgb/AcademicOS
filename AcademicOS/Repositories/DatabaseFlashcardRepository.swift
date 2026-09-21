import Foundation

/// Real database-backed flashcard repository implementing spaced repetition scheduling.
public final class DatabaseFlashcardRepository: FlashcardRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getFlashcards(forCourseId courseId: UUID) async throws -> [Flashcard] {
        let all: [Flashcard] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    public func getAllDueFlashcards() async throws -> [Flashcard] {
        let all: [Flashcard] = try await localStore.fetchAll()
        let now = Date()
        return all.filter { $0.nextReviewDate <= now }.sorted { $0.difficulty > $1.difficulty }
    }

    public func saveFlashcard(_ card: Flashcard) async throws {
        try await localStore.save(card)
    }

    public func updateReview(id: UUID, difficulty: Int) async throws {
        guard var card: Flashcard = try await localStore.fetch(id: id) else { return }

        card.reviewCount += 1
        card.difficulty = difficulty

        // SM-2 Spaced Repetition simplified calculation
        if difficulty >= 3 { // Success
            if card.reviewCount == 1 {
                card.intervalDays = 1
            } else if card.reviewCount == 2 {
                card.intervalDays = 6
            } else {
                card.intervalDays = Int(Double(card.intervalDays) * card.easeFactor)
            }
        } else { // Hard / Fail
            card.intervalDays = 1
        }

        card.nextReviewDate = Calendar.current.date(byAdding: .day, value: max(1, card.intervalDays), to: Date()) ?? Date()
        try await localStore.save(card)
    }

    public func deleteFlashcard(id: UUID) async throws {
        try await localStore.delete(id: id)
    }
}
