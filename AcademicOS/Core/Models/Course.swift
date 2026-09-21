import Foundation

/// Status of an academic course enrollment.
public enum CourseStatus: String, Codable, Sendable, CaseIterable {
    case active = "Active"
    case archived = "Archived"
    case completed = "Completed"
}

/// Represents an academic course enrolled in by the student.
public struct Course: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var code: String
    public var name: String
    public var department: String
    public var credits: Int
    public var ects: Int
    public var semesterId: UUID
    public var professor: Professor?
    public var colorHex: String
    public var iconName: String
    public var aiMemorySummary: String
    public var lectureRoom: String
    public var weeklyClassDay: String // e.g., "Monday"
    public var startTime: String // e.g., "09:00"
    public var endTime: String // e.g., "11:50"
    public var notes: String
    public var status: CourseStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        code: String,
        name: String,
        department: String = "",
        credits: Int = 3,
        ects: Int = 5,
        semesterId: UUID,
        professor: Professor? = nil,
        colorHex: String = "#4F46E5",
        iconName: String = "books.vertical.fill",
        aiMemorySummary: String = "Isolated course memory initialized.",
        lectureRoom: String = "Amphi 1",
        weeklyClassDay: String = "Monday",
        startTime: String = "09:00",
        endTime: String = "11:50",
        notes: String = "",
        status: CourseStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.department = department
        self.credits = credits
        self.ects = ects
        self.semesterId = semesterId
        self.professor = professor
        self.colorHex = colorHex
        self.iconName = iconName
        self.aiMemorySummary = aiMemorySummary
        self.lectureRoom = lectureRoom
        self.weeklyClassDay = weeklyClassDay
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var weeklySchedule: String {
        return "\(weeklyClassDay) \(startTime) - \(endTime)"
    }
}
