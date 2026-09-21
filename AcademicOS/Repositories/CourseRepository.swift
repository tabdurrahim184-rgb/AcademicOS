import Foundation

/// Concrete repository implementation for courses and course sub-modules.
public final class CourseRepository: CourseRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getCourses() async throws -> [Course] {
        return try await localStore.fetchAll()
    }

    public func getCourse(id: UUID) async throws -> Course? {
        return try await localStore.fetch(id: id)
    }

    public func saveCourse(_ course: Course) async throws {
        try await localStore.save(course)
    }

    public func deleteCourse(id: UUID) async throws {
        try await localStore.delete(id: id)
    }

    // Notes
    public func getNotes(forCourseId courseId: UUID) async throws -> [Note] {
        let allNotes: [Note] = try await localStore.fetchAll()
        return allNotes.filter { $0.courseId == courseId }
    }

    public func saveNote(_ note: Note) async throws {
        try await localStore.save(note)
    }

    // Lectures
    public func getLectures(forCourseId courseId: UUID) async throws -> [LectureSession] {
        let all: [LectureSession] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
    }

    public func saveLecture(_ lecture: LectureSession) async throws {
        try await localStore.save(lecture)
    }

    // Exams
    public func getExams(forCourseId courseId: UUID) async throws -> [Exam] {
        let all: [Exam] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
    }

    public func saveExam(_ exam: Exam) async throws {
        try await localStore.save(exam)
    }

    // Assignments
    public func getAssignments(forCourseId courseId: UUID) async throws -> [Assignment] {
        let all: [Assignment] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
    }

    public func saveAssignment(_ assignment: Assignment) async throws {
        try await localStore.save(assignment)
    }

    // Flashcards
    public func getFlashcards(forCourseId courseId: UUID) async throws -> [Flashcard] {
        let all: [Flashcard] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
    }

    public func saveFlashcard(_ card: Flashcard) async throws {
        try await localStore.save(card)
    }

    // Documents
    public func getDocuments(forCourseId courseId: UUID) async throws -> [AcademicDocument] {
        let all: [AcademicDocument] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }
    }

    public func saveDocument(_ doc: AcademicDocument) async throws {
        try await localStore.save(doc)
    }
}
