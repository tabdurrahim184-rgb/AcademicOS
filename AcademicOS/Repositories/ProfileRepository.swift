import Foundation

/// Concrete repository for user profile and GPA statistics.
public final class ProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getProfile() async throws -> StudentProfile {
        let all: [StudentProfile] = try await localStore.fetchAll()
        if let profile = all.first {
            return profile
        }
        let initialProfile = StudentProfile()
        try await localStore.save(initialProfile)
        return initialProfile
    }

    public func updateProfile(_ profile: StudentProfile) async throws {
        try await localStore.save(profile)
    }

    public func getGPARecord() async throws -> GPARecord {
        let all: [GPARecord] = try await localStore.fetchAll()
        if let first = all.first {
            return first
        }
        let defaultGPA = GPARecord(
            semesterId: UUID(),
            semesterName: "Fall 2026",
            currentGPA: 3.84,
            cumulativeGPA: 3.78,
            totalCreditsAttempted: 112,
            totalCreditsEarned: 112,
            targetGraduationGPA: 3.80,
            honorRoll: true
        )
        try await localStore.save(defaultGPA)
        return defaultGPA
    }
}
