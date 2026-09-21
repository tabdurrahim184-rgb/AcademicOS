import Foundation

/// SQLite-backed repository for detected professor emphasis and exam hints.
public final class DatabaseProfessorEmphasisRepository: ProfessorEmphasisRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getEmphasis(forCourseId courseId: UUID) async throws -> [ProfessorEmphasis] {
        let all: [ProfessorEmphasis] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.startTime < $1.startTime }
    }

    public func getEmphasis(forRecordingId recordingId: UUID) async throws -> [ProfessorEmphasis] {
        let all: [ProfessorEmphasis] = try await localStore.fetchAll()
        return all.filter { $0.recordingId == recordingId }.sorted { $0.startTime < $1.startTime }
    }

    public func saveEmphasis(_ item: ProfessorEmphasis) async throws {
        try await localStore.save(item)
    }

    public func saveAllEmphasis(_ items: [ProfessorEmphasis]) async throws {
        try await localStore.saveAll(items)
    }

    public func deleteEmphasis(id: UUID) async throws {
        try await localStore.delete(type: ProfessorEmphasis.self, id: id)
    }
}
