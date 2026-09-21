import XCTest
import Foundation
@testable import AcademicOS

final class CourseContextIsolationTests: XCTestCase {
    var localStore: LocalStoreProtocol!
    var courseRepo: CourseRepositoryProtocol!
    var notesRepo: NotesRepositoryProtocol!
    var recRepo: RecordingRepositoryProtocol!
    var examRepo: ExamRepositoryProtocol!
    var taskRepo: TaskRepositoryProtocol!
    var memRepo: AIMemoryRepositoryProtocol!
    var contextBuilder: CourseContextBuilder!

    let courseAId = UUID()
    let courseBId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        courseRepo = DatabaseCourseRepository(localStore: localStore)
        notesRepo = DatabaseNotesRepository(localStore: localStore)
        recRepo = DatabaseRecordingRepository(localStore: localStore)
        examRepo = DatabaseExamRepository(localStore: localStore)
        taskRepo = DatabaseTaskRepository(localStore: localStore)
        memRepo = DatabaseAIMemoryRepository(localStore: localStore)

        contextBuilder = CourseContextBuilder(
            courseRepo: courseRepo,
            notesRepo: notesRepo,
            recordingRepo: recRepo,
            examRepo: examRepo,
            taskRepo: taskRepo,
            memoryRepo: memRepo
        )

        // Seed Course A
        let semId = UUID()
        let courseA = Course(
            id: courseAId,
            code: "COMM101",
            name: "Communication Law",
            semesterId: semId
        )
        try await courseRepo.saveCourse(courseA)

        let noteA = Note(
            courseId: courseAId,
            title: "Freedom of Speech Case Law",
            rawContent: "Article 26 guarantees freedom of thought and expression."
        )
        try await notesRepo.saveNote(noteA)

        let memoryA = AIMemoryEntry(
            courseId: courseAId,
            topic: "Freedom of Expression",
            content: "Crucial judicial precedents in press freedom.",
            type: .concept
        )
        try await memRepo.saveMemory(memoryA)

        // Seed Course B
        let courseB = Course(
            id: courseBId,
            code: "SOC201",
            name: "Modern Sociology",
            semesterId: semId
        )
        try await courseRepo.saveCourse(courseB)

        let noteB = Note(
            courseId: courseBId,
            title: "Bourdieu and Cultural Capital",
            rawContent: "Cultural capital exists in three states: embodied, objectified, institutionalized."
        )
        try await notesRepo.saveNote(noteB)
    }

    func testCourseAContextDoesNotContainCourseBNotes() async throws {
        let contextA = try await contextBuilder.buildContext(courseId: courseAId)

        let contextString = contextA.values.joined(separator: " ")
        XCTAssertTrue(contextString.contains("COMM101"))
        XCTAssertTrue(contextString.contains("Freedom of Speech"))

        // Strict isolation: Course B content must be 100% absent
        XCTAssertFalse(contextString.contains("SOC201"), "Course A context must not leak Course B code.")
        XCTAssertFalse(contextString.contains("Bourdieu"), "Course A context must not leak Course B notes.")
        XCTAssertFalse(contextString.contains("Cultural Capital"), "Course A context must not leak Course B topics.")
    }

    func testCrossCourseBriefingForCommanderOnly() async throws {
        let briefing = try await contextBuilder.buildCrossCourseBriefingContext()
        let text = briefing.values.joined(separator: " ")

        XCTAssertTrue(text.contains("COMM101"))
        XCTAssertTrue(text.contains("SOC201"))
    }
}
