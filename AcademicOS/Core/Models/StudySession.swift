import Foundation

/// Represents a focused study session logged by the student or guided by an agent.
public struct StudySession: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var title: String
    public var scheduledDate: Date
    public var targetDurationMinutes: Int
    public var actualDurationMinutes: Int
    public var agentAssisted: Bool
    public var agentName: String?
    public var focusRating: Int // 1 to 5
    public var notes: String
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        title: String,
        scheduledDate: Date = Date(),
        targetDurationMinutes: Int = 45,
        actualDurationMinutes: Int = 0,
        agentAssisted: Bool = false,
        agentName: String? = nil,
        focusRating: Int = 4,
        notes: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.scheduledDate = scheduledDate
        self.targetDurationMinutes = targetDurationMinutes
        self.actualDurationMinutes = actualDurationMinutes
        self.agentAssisted = agentAssisted
        self.agentName = agentName
        self.focusRating = focusRating
        self.notes = notes
        self.isCompleted = isCompleted
    }
}
