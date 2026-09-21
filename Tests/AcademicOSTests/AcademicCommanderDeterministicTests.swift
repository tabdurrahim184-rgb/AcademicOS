import XCTest
import Foundation
@testable import AcademicOS

final class AcademicCommanderDeterministicTests: XCTestCase {
    var localStore: LocalStoreProtocol!
    var examRepo: ExamRepositoryProtocol!
    var taskRepo: TaskRepositoryProtocol!
    var courseRepo: CourseRepositoryProtocol!
    var commander: AcademicCommanderAgent!

    let courseId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        examRepo = DatabaseExamRepository(localStore: localStore)
        taskRepo = DatabaseTaskRepository(localStore: localStore)
        courseRepo = DatabaseCourseRepository(localStore: localStore)

        let online = GeminiOnlineAIProvider()
        let local = AppleLocalAIProvider()
        let router = AIRouter(onlineProvider: online, localProvider: local, networkMonitor: NetworkMonitor.shared)

        commander = AcademicCommanderAgent(
            router: router,
            courseRepo: courseRepo,
            examRepo: examRepo,
            taskRepo: taskRepo
        )

        // Seed real exam in SQLite
        let exam = Exam(
            courseId: courseId,
            title: "İletişim Hukuku Vizesi",
            examType: "Vize",
            examDate: "2026-11-15",
            room: "Amfi 3",
            weightPercentage: 40
        )
        try await examRepo.saveExam(exam)

        // Seed real task in SQLite
        let task = AcademicTask(
            courseId: courseId,
            title: "Anayasa Mahkemesi Karar İncelemesi",
            dueDate: "2026-10-20",
            isCompleted: false
        )
        try await taskRepo.saveTask(task)
    }

    func testNearestExamReadsExactSQLiteRecordWithoutHallucination() async throws {
        let result = try await commander.execute(task: "En yakın sınavım hangisi?", context: [:])

        XCTAssertTrue(result.contains("İletişim Hukuku Vizesi"), "Must return verified exam title from SQLite.")
        XCTAssertTrue(result.contains("2026-11-15"), "Must return exact exam date from SQLite.")
        XCTAssertTrue(result.contains("%40"), "Must return verified exam weight from SQLite.")
    }

    func testPendingAssignmentsReadFromSQLite() async throws {
        let result = try await commander.execute(task: "Bu hafta teslim etmem gerekenler neler?", context: [:])

        XCTAssertTrue(result.contains("Anayasa Mahkemesi Karar İncelemesi"), "Must return verified pending task title.")
        XCTAssertTrue(result.contains("2026-10-20"), "Must return verified due date.")
    }
}
