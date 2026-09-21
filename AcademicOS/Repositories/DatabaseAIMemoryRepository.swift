import Foundation

/// SQLite-backed repository for isolated course AI memory items.
public final class DatabaseAIMemoryRepository: AIMemoryRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getMemories(forCourseId courseId: UUID) async throws -> [AIMemoryEntry] {
        let all: [AIMemoryEntry] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
            .sorted {
                // Pinned items first, then higher importance, then newest
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned && !$1.isPinned
                }
                if $0.importanceScore != $1.importanceScore {
                    return $0.importanceScore > $1.importanceScore
                }
                return $0.createdAt > $1.createdAt
            }
    }

    public func getMemories(forCourseId courseId: UUID, type: AIMemoryType) async throws -> [AIMemoryEntry] {
        let all = try await getMemories(forCourseId: courseId)
        return all.filter { $0.type == type }
    }

    public func saveMemory(_ entry: AIMemoryEntry) async throws {
        try await localStore.save(entry)
    }

    public func deleteMemory(id: UUID) async throws {
        try await localStore.delete(type: AIMemoryEntry.self, id: id)
    }

    public func togglePin(id: UUID) async throws {
        if var memory: AIMemoryEntry = try await localStore.fetch(id: id) {
            memory.isPinned.toggle()
            memory.updatedAt = Date()
            try await localStore.save(memory)
        }
    }

    public func searchMemories(query: String, courseId: UUID) async throws -> [AIMemoryEntry] {
        let courseMemories = try await getMemories(forCourseId: courseId)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return courseMemories
        }
        let lower = query.lowercased()
        return courseMemories.filter {
            $0.topic.lowercased().contains(lower) ||
            $0.content.lowercased().contains(lower) ||
            $0.tags.contains(where: { $0.lowercased().contains(lower) })
        }
    }
}
