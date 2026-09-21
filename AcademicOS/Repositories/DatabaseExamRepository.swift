import Foundation

/// Real database-backed exam repository.
public final class DatabaseExamRepository: ExamRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getExams(forCourseId courseId: UUID) async throws -> [Exam] {
        let all: [Exam] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.examDate < $1.examDate }
    }

    public func getAllExams() async throws -> [Exam] {
        let all: [Exam] = try await localStore.fetchAll()
        return all.sorted { $0.examDate < $1.examDate }
    }

    public func getExam(id: UUID) async throws -> Exam? {
        return try await localStore.fetch(id: id)
    }

    public func saveExam(_ exam: Exam) async throws {
        try await localStore.save(exam)
    }

    public func deleteExam(id: UUID) async throws {
        try await localStore.delete(id: id)
    }
}
