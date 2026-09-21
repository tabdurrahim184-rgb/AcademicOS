import Foundation

/// Concrete repository for university graduation progress tracking.
public final class GraduationRepository: GraduationRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getGraduationProgress() async throws -> GraduationProgress {
        let all: [GraduationProgress] = try await localStore.fetchAll()
        if let first = all.first {
            return first
        }
        // Fallback default
        let defaultProgress = GraduationProgress(
            codename: "OPERATION GRADUATION",
            daysRemaining: 126,
            totalCreditsRequired: 240,
            completedCredits: 208,
            progressPercentage: 87.0
        )
        try await localStore.save(defaultProgress)
        return defaultProgress
    }

    public func updateGraduationProgress(_ progress: GraduationProgress) async throws {
        try await localStore.save(progress)
    }
}
