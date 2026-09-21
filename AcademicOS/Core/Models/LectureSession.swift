import Foundation

/// Attendance status for a lecture session.
public enum AttendanceStatus: String, Codable, Sendable, CaseIterable {
    case present = "Present"
    case absent = "Absent"
    case cancelled = "Class Cancelled"
    case upcoming = "Scheduled"
}

/// Recording status for a lecture session.
public enum LectureRecordingState: String, Codable, Sendable, CaseIterable {
    case none = "Not Recorded"
    case recording = "Recording Active"
    case recorded = "Recorded"
    case transcribing = "Transcribing"
    case transcribed = "Transcribed"
}

/// Represents an individual scheduled lecture session for a course.
public struct LectureSession: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var topic: String
    public var sessionDate: Date
    public var startTime: String // e.g., "09:00"
    public var endTime: String // e.g., "10:50"
    public var durationMinutes: Int
    public var classroom: String
    public var professorName: String
    public var attendanceStatus: AttendanceStatus
    public var manualNotes: String
    public var recordingState: LectureRecordingState
    public var recordingId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        topic: String,
        sessionDate: Date = Date(),
        startTime: String = "09:00",
        endTime: String = "10:50",
        durationMinutes: Int = 110,
        classroom: String = "Amphi 1",
        professorName: String = "",
        attendanceStatus: AttendanceStatus = .upcoming,
        manualNotes: String = "",
        recordingState: LectureRecordingState = .none,
        recordingId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.topic = topic
        self.sessionDate = sessionDate
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.classroom = classroom
        self.professorName = professorName
        self.attendanceStatus = attendanceStatus
        self.manualNotes = manualNotes
        self.recordingState = recordingState
        self.recordingId = recordingId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var title: String {
        return topic
    }

    public var room: String {
        return classroom
    }

    public var isRecorded: Bool {
        return recordingState == .recorded || recordingState == .transcribed
    }
}
