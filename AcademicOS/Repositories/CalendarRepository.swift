import Foundation

/// Concrete repository implementation for calendar events and scheduled academic milestones.
public final class CalendarRepository: CalendarRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getAllExams() async throws -> [Exam] {
        let exams: [Exam] = try await localStore.fetchAll()
        return exams.sorted { $0.examDate < $1.examDate }
    }

    public func getAllAssignments() async throws -> [Assignment] {
        let assignments: [Assignment] = try await localStore.fetchAll()
        return assignments.sorted { $0.dueDate < $1.dueDate }
    }

    public func getAllLectures() async throws -> [LectureSession] {
        let lectures: [LectureSession] = try await localStore.fetchAll()
        return lectures.sorted { $0.sessionDate < $1.sessionDate }
    }

    public func getAllStudySessions() async throws -> [StudySession] {
        let sessions: [StudySession] = try await localStore.fetchAll()
        return sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    public func saveStudySession(_ session: StudySession) async throws {
        try await localStore.save(session)
    }
}
