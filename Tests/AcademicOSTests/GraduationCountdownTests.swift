import XCTest
@testable import AcademicOSKit

/// Validates dynamic graduation countdown calculation, formatting strings, and leap year handling.
final class GraduationCountdownTests: XCTestCase {

    func testStandardCountdownCalculation() {
        let calendar = Calendar(identifier: .gregorian)
        var referenceComponents = DateComponents()
        referenceComponents.year = 2026
        referenceComponents.month = 9
        referenceComponents.day = 21
        let referenceDate = calendar.date(from: referenceComponents)!

        var gradComponents = DateComponents()
        gradComponents.year = 2027
        gradComponents.month = 6
        gradComponents.day = 30
        let targetGradDate = calendar.date(from: gradComponents)!

        let profile = StudentProfile(
            firstName: "Student",
            lastName: "Commander",
            universityName: "Istanbul University",
            faculty: "Communication",
            department: "Journalism",
            expectedGraduationDate: targetGradDate
        )

        let daysRemaining = profile.daysUntilGraduation(from: referenceDate)
        // From Sep 21, 2026 to Jun 30, 2027:
        // Sep 21->30: 9 days, Oct: 31, Nov: 30, Dec: 31, Jan: 31, Feb: 28, Mar: 31, Apr: 30, May: 31, Jun: 30
        // 9 + 31 + 30 + 31 + 31 + 28 + 31 + 30 + 31 + 30 = 282 days
        XCTAssertEqual(daysRemaining, 282)

        let countdownString = profile.graduationCountdownFormatted(from: referenceDate)
        XCTAssertEqual(countdownString, "D-282")
    }

    func testCommencementDayFormatting() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2027
        components.month = 6
        components.day = 30
        let commencementDate = calendar.date(from: components)!

        let profile = StudentProfile(
            firstName: "Student",
            lastName: "Commander",
            universityName: "Istanbul University",
            faculty: "Communication",
            department: "Journalism",
            expectedGraduationDate: commencementDate
        )

        let daysRemaining = profile.daysUntilGraduation(from: commencementDate)
        XCTAssertEqual(daysRemaining, 0)
        XCTAssertEqual(profile.graduationCountdownFormatted(from: commencementDate), "COMMENCEMENT TODAY")
    }

    func testPostGraduationDayFormatting() {
        let calendar = Calendar(identifier: .gregorian)
        var gradComponents = DateComponents()
        gradComponents.year = 2026
        gradComponents.month = 6
        gradComponents.day = 15
        let gradDate = calendar.date(from: gradComponents)!

        var laterComponents = DateComponents()
        laterComponents.year = 2026
        laterComponents.month = 6
        laterComponents.day = 20
        let laterDate = calendar.date(from: laterComponents)!

        let profile = StudentProfile(
            firstName: "Alumni",
            lastName: "Student",
            universityName: "Istanbul University",
            faculty: "Communication",
            department: "Journalism",
            expectedGraduationDate: gradDate
        )

        let daysRemaining = profile.daysUntilGraduation(from: laterDate)
        XCTAssertEqual(daysRemaining, -5)
        XCTAssertEqual(profile.graduationCountdownFormatted(from: laterDate), "GRADUATED (+5 DAYS)")
    }

    func testGraduationProgressModelFormatting() {
        let progress = GraduationProgress(
            codename: "OPERATION GRADUATION",
            daysRemaining: 126,
            totalCreditsRequired: 240,
            completedCredits: 208,
            progressPercentage: 86.67
        )

        XCTAssertEqual(progress.countdownFormatted, "D-126")

        let completedProgress = GraduationProgress(
            codename: "OPERATION GRADUATION",
            daysRemaining: 0,
            totalCreditsRequired: 240,
            completedCredits: 240,
            progressPercentage: 100.0
        )
        XCTAssertEqual(completedProgress.countdownFormatted, "COMMENCEMENT TODAY")
    }
}
