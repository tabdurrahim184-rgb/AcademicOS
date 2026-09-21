import Foundation

/// Coordinates selective promotion of high-yield academic insights into persistent course AI memory.
public final class MemoryPromotionService: Sendable {
    private let memoryRepo: AIMemoryRepositoryProtocol

    public init(memoryRepo: AIMemoryRepositoryProtocol) {
        self.memoryRepo = memoryRepo
    }

    /// Automatically promotes verified professor emphasis and exam hints into course AI memory.
    public func promoteEmphasisItem(_ emphasis: ProfessorEmphasis) async throws -> AIMemoryEntry {
        let type: AIMemoryType
        let importance: Double

        switch emphasis.classification {
        case .explicitExamHint:
            type = .examHint
            importance = 1.0
        case .professorEmphasis:
            type = .professorEmphasis
            importance = 0.9
        case .importantDefinition:
            type = .definition
            importance = 0.85
        case .assignmentInstruction:
            type = .assignmentInstruction
            importance = 0.8
        case .importantExample:
            type = .concept
            importance = 0.75
        case .reviewRecommendation:
            type = .importantFact
            importance = 0.7
        }

        let entry = AIMemoryEntry(
            courseId: emphasis.courseId,
            lectureSessionId: emphasis.lectureSessionId,
            topic: emphasis.classification.title,
            content: emphasis.exactSourceSnippet,
            type: type,
            importanceScore: importance,
            sourceReference: "Lecture at \(emphasis.formattedTimestamp)",
            tags: [emphasis.classification.rawValue, "auto_promoted"],
            isUserVerified: false,
            isPinned: emphasis.classification == .explicitExamHint
        )

        try await memoryRepo.saveMemory(entry)
        return entry
    }

    /// Promotes an academic definition extracted from a lecture.
    public func promoteDefinition(
        courseId: UUID,
        term: String,
        definition: String,
        source: String
    ) async throws -> AIMemoryEntry {
        let entry = AIMemoryEntry(
            courseId: courseId,
            topic: term,
            content: definition,
            type: .definition,
            importanceScore: 0.85,
            sourceReference: source,
            tags: ["definition", "key_term"],
            isUserVerified: true
        )
        try await memoryRepo.saveMemory(entry)
        return entry
    }

    /// Allows student to manually create or pin an important course rule or concept.
    public func createManualMemory(
        courseId: UUID,
        topic: String,
        content: String,
        type: AIMemoryType = .manualMemory
    ) async throws -> AIMemoryEntry {
        let entry = AIMemoryEntry(
            courseId: courseId,
            topic: topic,
            content: content,
            type: type,
            importanceScore: 0.9,
            sourceReference: "Manual Student Note",
            tags: ["manual", "student_pinned"],
            isUserVerified: true,
            isPinned: true
        )
        try await memoryRepo.saveMemory(entry)
        return entry
    }
}
