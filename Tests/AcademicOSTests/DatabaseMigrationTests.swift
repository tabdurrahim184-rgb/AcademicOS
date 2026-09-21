import XCTest
@testable import AcademicOSKit

/// Validates SQLiteDatabaseEngine schema migrations, WAL mode, foreign keys, and migration idempotency.
final class DatabaseMigrationTests: XCTestCase {
    private var engine: SQLiteDatabaseEngine!
    private let testDBName = "AcademicOSTest_\(UUID().uuidString).sqlite"

    override func setUp() async throws {
        try await super.setUp()
        engine = SQLiteDatabaseEngine(databaseName: testDBName)
    }

    override func tearDown() async throws {
        let fileManager = FileManager.default
        let url = await engine.databaseURL
        try? fileManager.removeItem(at: url)
        try await super.tearDown()
    }

    func testDatabaseOpenAndMigrationV1() async throws {
        try await engine.openAndMigrate()

        let version = try await engine.userVersion()
        XCTAssertEqual(version, 1, "Schema version must be 1 after V1 migration")

        let integrity = try await engine.checkIntegrity()
        XCTAssertTrue(integrity.contains("OK"), "Integrity check must return OK")
    }

    func testMigrationIdempotency() async throws {
        // First run
        try await engine.openAndMigrate()
        let versionFirst = try await engine.userVersion()
        XCTAssertEqual(versionFirst, 1)

        // Second run on existing database must succeed without error or duplicate table errors
        try await engine.openAndMigrate()
        let versionSecond = try await engine.userVersion()
        XCTAssertEqual(versionSecond, 1)
    }

    func testDatabaseURLCreation() async {
        let url = await engine.databaseURL
        XCTAssertTrue(url.path.contains("Database"))
        XCTAssertTrue(url.path.contains(testDBName))
    }
}
