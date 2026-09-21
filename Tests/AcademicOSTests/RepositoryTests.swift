import XCTest
@testable import AcademicOSKit

final class RepositoryTests: XCTestCase {
    var inMemoryStore: InMemoryDatabaseManager!
    var courseRepo: CourseRepository!
    var taskRepo: TaskRepository!

    override func setUp() async throws {
        try await super.setUp()
        inMemoryStore = InMemoryDatabaseManager()
        courseRepo = CourseRepository(localStore: inMemoryStore)
        taskRepo = TaskRepository(localStore: inMemoryStore)
    }

    func testSaveAndRetrieveCourse() async throws {
        let course = Course(
            code: "COMM 403",
            name: "Communication Theories",
            department: "Journalism",
            credits: 4,
            semesterId: UUID()
        )

        try await courseRepo.saveCourse(course)
        let retrieved = try await courseRepo.getCourse(id: course.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Communication Theories")
        XCTAssertEqual(retrieved?.credits, 4)
    }

    func testTaskCompletionToggle() async throws {
        let task = AcademicTask(
            title: "Study for Communication Law",
            isCompleted: false
        )

        try await taskRepo.saveTask(task)
        try await taskRepo.toggleTaskCompletion(id: task.id)

        let tasks = try await taskRepo.getTasks()
        let updated = tasks.first(where: { $0.id == task.id })

        XCTAssertNotNil(updated)
        XCTAssertTrue(updated?.isCompleted ?? false)
        XCTAssertNotNil(updated?.completedAt)
    }
}
