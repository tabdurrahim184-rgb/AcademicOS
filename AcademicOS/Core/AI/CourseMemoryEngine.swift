import Foundation

/// Abstraction for memory retrieval engines, allowing local deterministic search now and vector search later.
public protocol CourseMemoryRetrieverProtocol: Sendable {
    func retrieveMemories(forCourseId courseId: UUID, query: String, limit: Int) async throws -> [AIMemoryEntry]
}

/// Deterministic local course memory retrieval engine.
/// Applies course isolation, keyword matching, importance score ranking, recency weighting, and pinned priority.
public final class CourseMemoryEngine: CourseMemoryRetrieverProtocol, @unchecked Sendable {
    private let memoryRepo: AIMemoryRepositoryProtocol

    public init(memoryRepo: AIMemoryRepositoryProtocol) {
        self.memoryRepo = memoryRepo
    }

    public func retrieveMemories(forCourseId courseId: UUID, query: String, limit: Int = 10) async throws -> [AIMemoryEntry] {
        let memories = try await memoryRepo.getMemories(forCourseId: courseId)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(memories.prefix(limit))
        }

        let queryTokens = trimmed.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Rank memories deterministically
        let ranked = memories.map { entry -> (entry: AIMemoryEntry, score: Double) in
            var score: Double = 0.0

            // Pinned priority boost
            if entry.isPinned {
                score += 10.0
            }

            // User-verified boost
            if entry.isUserVerified {
                score += 3.0
            }

            // Importance baseline (0.0 to 1.0)
            score += entry.importanceScore * 5.0

            // Recency weighting (newer entries score higher)
            let ageDays = Date().timeIntervalSince(entry.createdAt) / 86400.0
            score += max(0.0, 2.0 - (ageDays * 0.05))

            // Keyword token matching
            let entryText = "\(entry.topic) \(entry.content) \(entry.tags.joined(separator: " "))".lowercased()
            for token in queryTokens {
                if entryText.contains(token) {
                    score += 4.0
                }
            }

            return (entry, score)
        }

        return ranked
            .sorted { $0.score > $1.score }
            .map { $0.entry }
            .prefix(limit)
            .map { $0 }
    }
}
