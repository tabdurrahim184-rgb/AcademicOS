import Foundation

/// Real database-backed notes repository supporting manual, transcript, and AI notes.
public final class DatabaseNotesRepository: NotesRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getNotes(forCourseId courseId: UUID) async throws -> [Note] {
        let all: [Note] = try await localStore.fetchAll()
        // Strict course isolation
        return all
            .filter { $0.courseId == courseId }
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned && !$1.isPinned
                }
                return $0.updatedAt > $1.updatedAt
            }
    }

    public func getNote(id: UUID) async throws -> Note? {
        return try await localStore.fetch(id: id)
    }

    public func searchNotes(query: String, courseId: UUID?) async throws -> [Note] {
        let all: [Note] = try await localStore.fetchAll()
        return all.filter { note in
            if let targetCourseId = courseId, note.courseId != targetCourseId {
                return false
            }
            if query.isEmpty { return true }
            return note.title.localizedCaseInsensitiveContains(query) ||
                   note.rawContent.localizedCaseInsensitiveContains(query) ||
                   note.aiStructuredSummary.localizedCaseInsensitiveContains(query) ||
                   note.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    public func saveNote(_ note: Note) async throws {
        var updated = note
        updated.updatedAt = Date()
        try await localStore.save(updated)
    }

    public func togglePin(id: UUID) async throws {
        if var note: Note = try await localStore.fetch(id: id) {
            note.isPinned.toggle()
            note.updatedAt = Date()
            try await localStore.save(note)
        }
    }

    public func deleteNote(id: UUID) async throws {
        try await localStore.delete(id: id)
    }
}
