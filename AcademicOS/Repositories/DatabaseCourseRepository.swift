import Foundation

/// Real database-backed course repository guaranteeing strict course isolation.
public final class DatabaseCourseRepository: CourseRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getCourses() async throws -> [Course] {
        let all: [Course] = try await localStore.fetchAll()
        return all.sorted { $0.code < $1.code }
    }

    public func getCourse(id: UUID) async throws -> Course? {
        return try await localStore.fetch(id: id)
    }

    public func getCourses(forSemesterId semesterId: UUID) async throws -> [Course] {
        let all: [Course] = try await localStore.fetchAll()
        return all.filter { $0.semesterId == semesterId }.sorted { $0.code < $1.code }
    }

    public func saveCourse(_ course: Course) async throws {
        var updated = course
        updated.updatedAt = Date()
        try await localStore.save(updated)
    }

    public func archiveCourse(id: UUID) async throws {
        if var course: Course = try await localStore.fetch(id: id) {
            course.status = .archived
            course.updatedAt = Date()
            try await localStore.save(course)
        }
    }

    public func deleteCourse(id: UUID) async throws {
        try await localStore.delete(Course.self, id: id)
    }
}
