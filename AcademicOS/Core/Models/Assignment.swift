import Foundation

/// Status of an assignment submission.
public enum AssignmentStatus: String, Codable, Sendable, CaseIterable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case submitted = "Submitted"
    case graded = "Graded"
    case overdue = "Overdue"
}

/// Represents a course project, homework, paper, or lab report.
public struct Assignment: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var title: String
    public var prompt: String
    public var dueDate: Date
    public var status: AssignmentStatus
    public var maxScore: Double
    public var achievedScore: Double?
    public var priority: TaskPriority
    public var submissionUrl: String?
    public var attachments: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        title: String,
        prompt: String = "",
        dueDate: Date,
        status: AssignmentStatus = .pending,
        maxScore: Double = 100.0,
        achievedScore: Double? = nil,
        priority: TaskPriority = .high,
        submissionUrl: String? = nil,
        attachments: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.prompt = prompt
        self.dueDate = dueDate
        self.status = status
        self.maxScore = maxScore
        self.achievedScore = achievedScore
        self.priority = priority
        self.submissionUrl = submissionUrl
        self.attachments = attachments
        self.createdAt = createdAt
    }
}
