import XCTest
@testable import AcademicOSKit

final class ModelValidationTests: XCTestCase {

    func testCourseSerializationAndDecoding() throws {
        let course = Course(
            code: "COMM 401",
            name: "Communication Law",
            department: "Media & Law",
            credits: 4,
            semesterId: UUID(),
            professor: Professor(name: "Dr. Selin Yılmaz"),
            colorHex: "#4F46E5",
            aiMemorySummary: "Legal doctrines regarding digital media"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(course)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Course.self, from: data)

        XCTAssertEqual(decoded.id, course.id)
        XCTAssertEqual(decoded.code, "COMM 401")
        XCTAssertEqual(decoded.credits, 4)
        XCTAssertEqual(decoded.professor?.name, "Dr. Selin Yılmaz")
    }

    func testGraduationProgressCountdown() {
        let grad = GraduationProgress(
            codename: "OPERATION GRADUATION",
            daysRemaining: 126,
            totalCreditsRequired: 240,
            completedCredits: 208,
            progressPercentage: 87.0
        )

        XCTAssertEqual(grad.countdownFormatted, "D-126")
        XCTAssertEqual(grad.progressPercentage, 87.0)
    }

    func testAcademicTaskPriorityOrder() {
        let urgent = TaskPriority.urgent
        let high = TaskPriority.high
        let medium = TaskPriority.medium
        let low = TaskPriority.low

        XCTAssertTrue(urgent.sortOrder < high.sortOrder)
        XCTAssertTrue(high.sortOrder < medium.sortOrder)
        XCTAssertTrue(medium.sortOrder < low.sortOrder)
    }
}
