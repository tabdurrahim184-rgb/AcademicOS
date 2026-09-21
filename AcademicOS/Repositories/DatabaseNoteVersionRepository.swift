import Foundation

/// SQLite-backed repository for managing versioned AI notes and preserving student edits.
public final class DatabaseNoteVersionRepository: NoteVersionRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getVersions(forNoteId noteId: UUID) async throws -> [AINoteVersion] {
        let all: [AINoteVersion] = try await localStore.fetchAll()
        return all.filter { $0.noteId == noteId }.sorted { $0.versionNumber > $1.versionNumber }
    }

    public func getVersions(forCourseId courseId: UUID) async throws -> [AINoteVersion] {
        let all: [AINoteVersion] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.createdAt > $1.createdAt }
    }

    public func getLatestVersion(forNoteId noteId: UUID, mode: NoteMode) async throws -> AINoteVersion? {
        let versions = try await getVersions(forNoteId: noteId)
        return versions.first { $0.mode == mode }
    }

    public func saveVersion(_ version: AINoteVersion) async throws {
        try await localStore.save(version)
    }

    public func deleteVersion(id: UUID) async throws {
        try await localStore.delete(type: AINoteVersion.self, id: id)
    }
}
