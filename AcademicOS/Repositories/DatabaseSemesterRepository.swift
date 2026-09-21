import Foundation

/// Real database-backed semester management repository.
public final class DatabaseSemesterRepository: SemesterRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getSemesters() async throws -> [Semester] {
        let all: [Semester] = try await localStore.fetchAll()
        return all.sorted { $0.startDate > $1.startDate }
    }

    public func getActiveSemester() async throws -> Semester? {
        let all: [Semester] = try await localStore.fetchAll()
        return all.first(where: { $0.isActive }) ?? all.first
    }

    public func saveSemester(_ semester: Semester) async throws {
        if semester.isActive {
            // Unset active on existing semesters to guarantee only one active
            let all: [Semester] = try await localStore.fetchAll()
            for var existing in all where existing.id != semester.id && existing.isActive {
                existing.isActive = false
                try await localStore.save(existing)
            }
        }
        try await localStore.save(semester)
    }

    public func setActiveSemester(id: UUID) async throws {
        let all: [Semester] = try await localStore.fetchAll()
        for var s in all {
            s.isActive = (s.id == id)
            try await localStore.save(s)
        }
    }

    public func deleteSemester(id: UUID) async throws {
        try await localStore.delete(Semester.self, id: id)
    }
}
