import Foundation

/// Represents semester GPA and cumulative academic standing.
public struct GPARecord: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var semesterId: UUID
    public var semesterName: String
    public var currentGPA: Double
    public var cumulativeGPA: Double
    public var totalCreditsAttempted: Int
    public var totalCreditsEarned: Int
    public var targetGraduationGPA: Double
    public var honorRoll: Bool
    public var recordedAt: Date

    public init(
        id: UUID = UUID(),
        semesterId: UUID,
        semesterName: String = "Spring 2026",
        currentGPA: Double = 3.84,
        cumulativeGPA: Double = 3.78,
        totalCreditsAttempted: Int = 112,
        totalCreditsEarned: Int = 112,
        targetGraduationGPA: Double = 3.80,
        honorRoll: Bool = true,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.semesterId = semesterId
        self.semesterName = semesterName
        self.currentGPA = currentGPA
        self.cumulativeGPA = cumulativeGPA
        self.totalCreditsAttempted = totalCreditsAttempted
        self.totalCreditsEarned = totalCreditsEarned
        self.targetGraduationGPA = targetGraduationGPA
        self.honorRoll = honorRoll
        self.recordedAt = recordedAt
    }
}
