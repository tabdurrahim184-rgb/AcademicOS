import XCTest
@testable import AcademicOSKit

final class UniversitySyncEngineTests: XCTestCase {
    var store: InMemoryDatabaseManager!
    var courseRepo: DatabaseCourseRepository!
    var examRepo: DatabaseExamRepository!
    var taskRepo: DatabaseTaskRepository!
    var calendarRepo: CalendarRepository!
    var universityRepo: DatabaseUniversityRepository!
    var connector: DemoUniversityConnector!
    var syncEngine: UniversitySyncEngine!

    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryDatabaseManager()
        courseRepo = DatabaseCourseRepository(localStore: store)
        examRepo = DatabaseExamRepository(localStore: store)
        taskRepo = DatabaseTaskRepository(localStore: store)
        calendarRepo = CalendarRepository(localStore: store)
        universityRepo = DatabaseUniversityRepository(localStore: store)
        connector = DemoUniversityConnector(simulatedDelayNanoseconds: 10_000)

        // Seed a sample semester and course for matching
        let semester = Semester(name: "Fall 2026", academicYear: "2026-2027", term: .fall, startDate: Date(), endDate: Date())
        try await store.save(semester)

        let course311 = Course(code: "CENG 311", name: "Operating Systems", department: "Computer Engineering", credits: 4, ects: 6, semesterId: semester.id)
        let course382 = Course(code: "CENG 382", name: "Analysis of Algorithms", department: "Computer Engineering", credits: 3, ects: 5, semesterId: semester.id)
        try await store.save(course311)
        try await store.save(course382)

        let portal = UniversityPortalConfig(name: "Test Portal", baseURL: "https://uzem.university.edu.tr", isActive: true)
        try await universityRepo.savePortal(portal)

        let docDownloader = UniversityDocumentDownloader(localStore: store)
        syncEngine = UniversitySyncEngine(
            connector: connector,
            universityRepo: universityRepo,
            courseRepo: courseRepo,
            examRepo: examRepo,
            taskRepo: taskRepo,
            calendarRepo: calendarRepo,
            documentDownloader: docDownloader
        )
    }

    func testPerformSyncImportsEntitiesSuccessfully() async throws {
        let report = try await syncEngine.performSync()

        XCTAssertEqual(report.portalName, connector.displayName)
        XCTAssertGreaterThan(report.newExamsCount, 0, "Exams should be imported")
        XCTAssertGreaterThan(report.newAssignmentsCount, 0, "Assignments should be imported")
        XCTAssertGreaterThan(report.newAnnouncementsCount, 0, "Announcements should be imported")
        XCTAssertGreaterThan(report.newGradesCount, 0, "Grades should be imported")

        // Verify exams in repository
        let allExams = try await examRepo.getAllExams()
        XCTAssertFalse(allExams.isEmpty)

        // Verify tasks in repository
        let allTasks = try await taskRepo.getAllTasks()
        XCTAssertFalse(allTasks.isEmpty)

        // Verify inbox items
        let inboxItems = try await universityRepo.fetchInboxItems()
        XCTAssertFalse(inboxItems.isEmpty)

        // Verify sync log recorded
        let logs = try await universityRepo.fetchRecentSyncLogs(limit: 5)
        XCTAssertFalse(logs.isEmpty)
        XCTAssertEqual(logs.first?.status, "Success")
    }

    func testConsecutiveSyncDetectsNoDuplicates() async throws {
        _ = try await syncEngine.performSync()
        let secondReport = try await syncEngine.performSync()

        XCTAssertEqual(secondReport.newExamsCount, 0, "Already imported exams should not be duplicated")
        XCTAssertEqual(secondReport.newAssignmentsCount, 0, "Already imported assignments should not be duplicated")
        XCTAssertEqual(secondReport.newAnnouncementsCount, 0, "Already imported announcements should not be duplicated")
    }
}
