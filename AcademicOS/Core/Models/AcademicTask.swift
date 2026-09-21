import Foundation

/// Priority level for academic tasks.
public enum TaskPriority: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    public var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

/// Category classification for academic tasks.
public enum TaskCategory: String, Codable, Sendable, CaseIterable {
    case mission = "Mission"
    case study = "Study"
    case revision = "Revision"
    case admin = "Admin"
    case project = "Project"
}

/// Represents an individual actionable academic task or mission item.
public struct AcademicTask: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID?
    public var title: String
    public var scheduledTime: String?
    public var dueDate: Date?
    public var estimatedMinutes: Int
    public var isCompleted: Bool
    public var priority: TaskPriority
    public var category: TaskCategory
    public var completedAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID? = nil,
        title: String,
        scheduledTime: String? = nil,
        dueDate: Date? = nil,
        estimatedMinutes: Int = 30,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        category: TaskCategory = .mission,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.scheduledTime = scheduledTime
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.priority = priority
        self.category = category
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}
