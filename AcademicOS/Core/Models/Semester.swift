import Foundation

/// Academic term classification.
public enum AcademicTerm: String, Codable, Sendable, CaseIterable {
    case fall = "Fall"
    case spring = "Spring"
    case summer = "Summer"
}

/// Represents an academic semester or university term.
public struct Semester: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var academicYear: String
    public var term: AcademicTerm
    public var startDate: Date
    public var endDate: Date
    public var isActive: Bool
    public var targetGPA: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        academicYear: String = "2026 - 2027",
        term: AcademicTerm = .fall,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date(),
        isActive: Bool = true,
        targetGPA: Double = 3.80,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.academicYear = academicYear
        self.term = term
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.targetGPA = targetGPA
        self.createdAt = createdAt
    }
}
