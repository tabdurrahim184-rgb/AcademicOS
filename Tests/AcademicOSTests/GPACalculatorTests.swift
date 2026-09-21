import XCTest
@testable import AcademicOSKit

final class GPACalculatorTests: XCTestCase {
    var calculator: GPACalculator!

    override func setUp() {
        super.setUp()
        calculator = GPACalculator()
    }

    func testGradePointsMapping() {
        XCTAssertEqual(GPACalculator.gradePoints(for: "AA"), 4.0)
        XCTAssertEqual(GPACalculator.gradePoints(for: "BA"), 3.5)
        XCTAssertEqual(GPACalculator.gradePoints(for: "BB"), 3.0)
        XCTAssertEqual(GPACalculator.gradePoints(for: "CB"), 2.5)
        XCTAssertEqual(GPACalculator.gradePoints(for: "CC"), 2.0)
        XCTAssertEqual(GPACalculator.gradePoints(for: "DC"), 1.5)
        XCTAssertEqual(GPACalculator.gradePoints(for: "DD"), 1.0)
        XCTAssertEqual(GPACalculator.gradePoints(for: "FD"), 0.5)
        XCTAssertEqual(GPACalculator.gradePoints(for: "FF"), 0.0)
    }

    func testScoreToLetterGradeConversion() {
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 95.0), "AA")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 87.0), "BA")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 82.0), "BB")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 76.0), "CB")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 71.0), "CC")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 66.0), "DC")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 61.0), "DD")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 55.0), "FD")
        XCTAssertEqual(GPACalculator.letterGrade(forScore: 40.0), "FF")
    }

    func testCalculateGPAWithECTS() {
        // CENG 311: 6 ECTS, AA (4.0) -> 24.0
        // CENG 382: 5 ECTS, BA (3.5) -> 17.5
        // MATH 251: 5 ECTS, BB (3.0) -> 15.0
        // CENG 351: 5 ECTS, CB (2.5) -> 12.5
        // Total points = 69.0, Total ECTS = 21, Expected GPA = 69.0 / 21 = 3.2857 -> 3.29
        let subjects = [
            GPASubjectItem(courseCode: "CENG 311", credits: 4, ects: 6, letterGrade: "AA"),
            GPASubjectItem(courseCode: "CENG 382", credits: 3, ects: 5, letterGrade: "BA"),
            GPASubjectItem(courseCode: "MATH 251", credits: 3, ects: 5, letterGrade: "BB"),
            GPASubjectItem(courseCode: "CENG 351", credits: 3, ects: 5, letterGrade: "CB")
        ]

        let result = calculator.calculateGPA(subjects: subjects, policy: .ectsCredits)
        XCTAssertEqual(result.gpa, 3.29)
        XCTAssertEqual(result.totalECTSAttempted, 21)
        XCTAssertEqual(result.totalECTSEarned, 21)
        XCTAssertEqual(result.honorStatus, "Honor (Onur)")
    }

    func testRequiredFutureGPACalculation() {
        // Current: 120 credits completed at 3.20 GPA. Target: 3.50 at 240 credits.
        // Current points = 120 * 3.20 = 384.0
        // Target points = 240 * 3.50 = 840.0
        // Remaining needed = 456.0 / 120 = 3.80
        let needed = calculator.requiredFutureGPA(
            currentGPA: 3.20,
            completedCredits: 120,
            targetGPA: 3.50,
            totalCreditsRequired: 240
        )
        XCTAssertEqual(needed, 3.80)
    }
}
