import Foundation

/// Real database-backed graduation repository dynamically computing countdown from student's target graduation date.
public final class DatabaseGraduationRepository: GraduationRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getGraduationProgress() async throws -> GraduationProgress {
        // Fetch real student profile to extract true expected graduation date
        let students: [StudentProfile] = try await localStore.fetchAll()
        let student = students.first

        let targetDate = student?.expectedGraduationDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let countdown = student?.graduationCountdown ?? {
            let cal = Calendar.current
            let days = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: targetDate)).day ?? 0)
            return (days, 0, 0, days)
        }()

        // Fetch courses to calculate total completed credits
        let courses: [Course] = try await localStore.fetchAll()
        let completedCourses = courses.filter { $0.status == .completed }
        let totalCompletedCredits = completedCourses.reduce(0) { $0 + ($1.ects > 0 ? $1.ects : $1.credits) }
        let totalRequiredCredits = 240 // European standard bachelor ECTS

        let calculatedProgress = min(100.0, (Double(totalCompletedCredits) / Double(totalRequiredCredits)) * 100.0)

        return GraduationProgress(
            codename: "OPERATION GRADUATION",
            targetGraduationDate: targetDate,
            daysRemaining: countdown.totalDays,
            totalCreditsRequired: totalRequiredCredits,
            completedCredits: totalCompletedCredits,
            progressPercentage: calculatedProgress,
            requirements: [
                GraduationRequirementItem(
                    title: "ECTS Degree Completion (240 ECTS)",
                    isSatisfied: totalCompletedCredits >= totalRequiredCredits,
                    category: "Degree Credits",
                    details: "\(totalCompletedCredits) / \(totalRequiredCredits) ECTS"
                ),
                GraduationRequirementItem(
                    title: "Target Graduation Deadline",
                    isSatisfied: countdown.totalDays > 0,
                    category: "Schedule",
                    details: "Projected: \(DateFormatter.localizedString(from: targetDate, dateStyle: .medium, timeStyle: .none))"
                )
            ]
        )
    }

    public func updateGraduationProgress(_ progress: GraduationProgress) async throws {
        try await localStore.save(progress)
    }
}
