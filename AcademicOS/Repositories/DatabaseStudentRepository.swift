import Foundation

/// Real database-backed student profile repository.
public final class DatabaseStudentRepository: StudentRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getStudent() async throws -> StudentProfile? {
        let students: [StudentProfile] = try await localStore.fetchAll()
        return students.first
    }

    public func saveStudent(_ student: StudentProfile) async throws {
        var updated = student
        updated.updatedAt = Date()
        try await localStore.save(updated)
    }

    public func deleteStudent() async throws {
        try await localStore.deleteAll(StudentProfile.self)
    }
}
