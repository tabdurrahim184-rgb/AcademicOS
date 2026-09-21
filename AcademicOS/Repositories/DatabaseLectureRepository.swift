import Foundation

/// Real database-backed lecture session repository.
public final class DatabaseLectureRepository: LectureRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getLectures(forCourseId courseId: UUID) async throws -> [LectureSession] {
        let all: [LectureSession] = try await localStore.fetchAll()
        // Strict course isolation
        return all.filter { $0.courseId == courseId }.sorted { $0.sessionDate < $1.sessionDate }
    }

    public func getLecture(id: UUID) async throws -> LectureSession? {
        return try await localStore.fetch(id: id)
    }

    public func getAllLectures() async throws -> [LectureSession] {
        let all: [LectureSession] = try await localStore.fetchAll()
        return all.sorted { $0.sessionDate < $1.sessionDate }
    }

    public func saveLecture(_ lecture: LectureSession) async throws {
        var updated = lecture
        updated.updatedAt = Date()
        try await localStore.save(updated)
    }

    public func deleteLecture(id: UUID) async throws {
        try await localStore.delete(id: id)
    }
}
