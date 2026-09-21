import Foundation

/// Individual requirement milestone towards university graduation.
public struct GraduationRequirementItem: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var isSatisfied: Bool
    public var category: String
    public var details: String

    public init(
        id: UUID = UUID(),
        title: String,
        isSatisfied: Bool,
        category: String = "Core",
        details: String = ""
    ) {
        self.id = id
        self.title = title
        self.isSatisfied = isSatisfied
        self.category = category
        self.details = details
    }
}

/// Represents the student's holistic progress towards graduation.
public struct GraduationProgress: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var codename: String
    public var targetGraduationDate: Date
    public var daysRemaining: Int
    public var totalCreditsRequired: Int
    public var completedCredits: Int
    public var progressPercentage: Double
    public var requirements: [GraduationRequirementItem]

    public init(
        id: UUID = UUID(),
        codename: String = "OPERATION GRADUATION",
        targetGraduationDate: Date = Calendar.current.date(byAdding: .day, value: 126, to: Date()) ?? Date(),
        daysRemaining: Int = 126,
        totalCreditsRequired: Int = 240,
        completedCredits: Int = 208,
        progressPercentage: Double = 87.0,
        requirements: [GraduationRequirementItem] = []
    ) {
        self.id = id
        self.codename = codename
        self.targetGraduationDate = targetGraduationDate
        self.daysRemaining = daysRemaining
        self.totalCreditsRequired = totalCreditsRequired
        self.completedCredits = completedCredits
        self.progressPercentage = progressPercentage
        self.requirements = requirements
    }

    public var countdownFormatted: String {
        return "D-\(daysRemaining)"
    }
}
