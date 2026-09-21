import Foundation

/// Types of academic assessments.
public enum ExamType: String, Codable, Sendable, CaseIterable {
    case midterm = "Midterm"
    case finalExam = "Final Exam"
    case quiz = "Quiz"
    case makeup = "Make-up Exam"
    case oralDefense = "Oral Defense"
}

/// Represents an upcoming or completed academic examination.
public struct Exam: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var title: String
    public var examType: ExamType
    public var examDate: Date
    public var room: String
    public var weightPercentage: Int
    public var targetGrade: Double?
    public var achievedGrade: Double?
    public var topicsCovered: [String]
    public var notes: String

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        title: String,
        examType: ExamType = .midterm,
        examDate: Date,
        room: String = "Hall B",
        weightPercentage: Int = 40,
        targetGrade: Double? = 90.0,
        achievedGrade: Double? = nil,
        topicsCovered: [String] = [],
        notes: String = ""
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.examType = examType
        self.examDate = examDate
        self.room = room
        self.weightPercentage = weightPercentage
        self.targetGrade = targetGrade
        self.achievedGrade = achievedGrade
        self.topicsCovered = topicsCovered
        self.notes = notes
    }
}
