import Foundation

/// SQLite-backed repository for tracking topic-level student academic mastery.
public final class DatabaseMasteryRepository: MasteryRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getMastery(forCourseId courseId: UUID) async throws -> [AcademicMastery] {
        let all: [AcademicMastery] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.masteryScore < $1.masteryScore }
    }

    public func getMastery(forCourseId courseId: UUID, topic: String) async throws -> AcademicMastery? {
        let courseMasteries = try await getMastery(forCourseId: courseId)
        return courseMasteries.first { $0.topic.lowercased() == topic.lowercased() }
    }

    public func saveMastery(_ record: AcademicMastery) async throws {
        try await localStore.save(record)
    }

    public func deleteMastery(id: UUID) async throws {
        try await localStore.delete(type: AcademicMastery.self, id: id)
    }
}
