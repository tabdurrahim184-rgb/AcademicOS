import XCTest
@testable import AcademicOSKit

final class Phase2ENEUConnectorTests: XCTestCase {
    var moodleConnector: NEUMoodleConnector!
    var portalConnector: NEUStudentPortalConnector!
    var transcriptParser: NEUTranscriptParser!
    var reconciliationService: NEUCourseReconciliationService!
    var masterConnector: NEUUniversityConnector!

    override func setUp() async throws {
        try await super.setUp()
        moodleConnector = NEUMoodleConnector()
        portalConnector = NEUStudentPortalConnector()
        transcriptParser = NEUTranscriptParser()
        reconciliationService = NEUCourseReconciliationService()
        masterConnector = NEUUniversityConnector(
            debimConnector: moodleConnector,
            studentPortalConnector: portalConnector,
            reconciliationService: reconciliationService,
            transcriptParser: transcriptParser
        )
    }

    // 1. Moodle Connector identifies DEBİM login page
    func test_moodle_connector_identifies_debim_login_page() {
        let loginURL = URL(string: "https://debim.neu.edu.tr/login/index.php")!
        let pageType = moodleConnector.identifyPageType(url: loginURL)
        XCTAssertEqual(pageType, .loginPage, "Should identify debim.neu.edu.tr/login/index.php as loginPage")
    }

    // 2. Moodle Connector identifies Google SAML redirect
    func test_moodle_connector_identifies_google_saml_redirect() {
        let samlURL = URL(string: "https://accounts.google.com/o/saml2/initsso?idpid=C03neu&spid=12345")!
        let pageType = moodleConnector.identifyPageType(url: samlURL)
        XCTAssertEqual(pageType, .googleSAMLRedirect, "Should identify accounts.google.com as googleSAMLRedirect")
    }

    // 3. Moodle Connector NEVER allows credential autofill on Google
    func test_moodle_connector_never_allows_credential_autofill_on_google() {
        let googleURL = URL(string: "https://accounts.google.com/signin/v2/identifier")!
        let canAutofill = moodleConnector.canAutofillCredentials(on: googleURL)
        XCTAssertFalse(canAutofill, "AcademicOS must NEVER allow credential autofill on accounts.google.com")
    }

    // 4. Student Portal Connector requires exact host
    func test_student_portal_connector_requires_exact_host() {
        let exactURL = URL(string: "https://register.neu.edu.tr/StudentCourse/Transcript")!
        XCTAssertTrue(portalConnector.isApprovedPortalURL(exactURL), "register.neu.edu.tr with HTTPS must be approved")

        let insecureURL = URL(string: "http://register.neu.edu.tr/StudentCourse/Transcript")!
        XCTAssertFalse(portalConnector.isApprovedPortalURL(insecureURL), "Insecure HTTP must be strictly rejected")
    }

    // 5. Student Portal Connector rejects non-portal hosts
    func test_student_portal_connector_rejects_non_portal_hosts() {
        let subdomainURL = URL(string: "https://other.neu.edu.tr/StudentCourse/Transcript")!
        XCTAssertFalse(portalConnector.isApprovedPortalURL(subdomainURL), "Arbitrary subdomains must not inherit permission")

        let spoofedURL = URL(string: "https://register.neu.edu.tr.attacker.com/StudentCourse/Transcript")!
        XCTAssertFalse(portalConnector.isApprovedPortalURL(spoofedURL), "Attacker domain with prefix must be rejected")
    }

    // 6. Transcript Parser extracts correct rows
    func test_transcript_parser_extracts_correct_rows() {
        let sampleHTML = """
        <html><body>
        <table class="table table-striped" id="transcriptTable">
            <thead>
                <tr>
                    <th>Dönem</th><th>Ders Kodu</th><th>Ders Adı</th><th>Kredi</th><th>AKTS</th><th>Harf Notu</th><th>Durum</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>2023-2024 Güz</td><td>CENG 311</td><td>System Analysis and Design</td><td>3</td><td>5</td><td>AA</td><td>Geçti</td>
                </tr>
                <tr>
                    <td>2023-2024 Güz</td><td>ECC 206</td><td>Signals and Systems</td><td>4</td><td>6</td><td>FF</td><td>Kaldı</td>
                </tr>
                <tr>
                    <td>2023-2024 Bahar</td><td>MATH 101</td><td>Calculus I</td><td>4</td><td>6</td><td>BA</td><td>Geçti</td>
                </tr>
            </tbody>
        </table>
        <div class="gpa-box">Genel Not Ortalaması (CGPA): 3.25</div>
        </body></html>
        """

        let summary = transcriptParser.parseTranscript(html: sampleHTML)
        XCTAssertEqual(summary.totalCourses, 3, "Should extract 3 courses")
        XCTAssertEqual(summary.totalSemesters, 2, "Should detect 2 unique semesters")
        XCTAssertEqual(summary.passedCount, 2, "Should find 2 passed courses")
        XCTAssertEqual(summary.failedCount, 1, "Should find 1 failed course")
        XCTAssertEqual(summary.portalReportedGPA, 3.25, "Should extract portal reported GPA 3.25")

        let ceng = summary.courses.first { $0.courseCode == "CENG 311" }
        XCTAssertNotNil(ceng)
        XCTAssertEqual(ceng?.grade, "AA")
        XCTAssertEqual(ceng?.credits, 3.0)
        XCTAssertTrue(ceng?.isPassed ?? false)

        let ecc = summary.courses.first { $0.courseCode == "ECC 206" }
        XCTAssertNotNil(ecc)
        XCTAssertEqual(ecc?.grade, "FF")
        XCTAssertFalse(ecc?.isPassed ?? true)
    }

    // 7. Transcript Parser marks unverified GPA
    func test_transcript_parser_marks_unverified_gpa() {
        let sampleHTML = "<table><tr><td>CENG 101</td><td>Intro to Programming</td><td>AA</td></tr></table>"
        let summary = transcriptParser.parseTranscript(html: sampleHTML)
        XCTAssertEqual(summary.gpaMappingStatus, "PORTAL IMPORT — UNVERIFIED GPA MAPPING", "Must label mapping as unverified")
        XCTAssertFalse(summary.isVerified, "isVerified must be false until catalog rules are verified")
    }

    // 8. Course Reconciliation deduplicates DEBİM and Portal courses
    func test_course_reconciliation_deduplicates_debim_and_portal_courses() {
        let debimCourse = RemoteCourse(
            remoteId: "debim-311",
            code: "ceng311",
            name: "System Analysis",
            instructor: "Dr. Smith",
            credits: 3,
            ects: 5
        )
        let portalCourse = NEUTranscriptCourse(
            academicYear: "2024-2025",
            semester: "Güz",
            courseCode: "CENG 311",
            courseName: "System Analysis",
            grade: "AA",
            credits: 3,
            ects: 5,
            isPassed: true
        )

        let report = reconciliationService.reconcile(
            debimCourses: [debimCourse],
            portalCourses: [portalCourse],
            localCourses: []
        )

        XCTAssertEqual(report.reconciledCourses.count, 1, "Should deduplicate into a single reconciled course")
        let first = report.reconciledCourses.first
        XCTAssertEqual(first?.canonicalCode, "CENG 311", "Canonical code should be formatted cleanly")
    }

    // 9. Course Reconciliation preserves both provenance badges
    func test_course_reconciliation_preserves_both_provenance_badges() {
        let debimCourse = RemoteCourse(
            remoteId: "debim-311",
            code: "CENG-311",
            name: "System Analysis",
            instructor: "Dr. Smith",
            credits: 3,
            ects: 5
        )
        let portalCourse = NEUTranscriptCourse(
            academicYear: "2024-2025",
            semester: "Güz",
            courseCode: "CENG 311",
            courseName: "System Analysis",
            grade: "AA",
            credits: 3,
            ects: 5,
            isPassed: true
        )

        let report = reconciliationService.reconcile(
            debimCourses: [debimCourse],
            portalCourses: [portalCourse],
            localCourses: []
        )

        let badges = report.reconciledCourses.first?.badges ?? []
        XCTAssertTrue(badges.contains(.debim), "Must contain DEBİM badge")
        XCTAssertTrue(badges.contains(.neuStudentPortal), "Must contain NEU STUDENT PORTAL badge")
    }

    // 10. Course Reconciliation flags source conflicts
    func test_course_reconciliation_flags_source_conflicts() {
        let debimCourse = RemoteCourse(
            remoteId: "debim-311",
            code: "CENG 311",
            name: "Software Engineering Studio",
            instructor: "Dr. Smith",
            credits: 4, // conflicting credits
            ects: 5
        )
        let portalCourse = NEUTranscriptCourse(
            academicYear: "2024-2025",
            semester: "Güz",
            courseCode: "CENG 311",
            courseName: "System Analysis and Design", // conflicting title
            grade: "AA",
            credits: 3,
            ects: 5,
            isPassed: true
        )

        let report = reconciliationService.reconcile(
            debimCourses: [debimCourse],
            portalCourses: [portalCourse],
            localCourses: []
        )

        XCTAssertFalse(report.allConflicts.isEmpty, "Discrepant title and credits must trigger SourceConflict records")
        let titleConflict = report.allConflicts.first { $0.fieldName == "courseName" }
        XCTAssertNotNil(titleConflict)
        XCTAssertTrue(titleConflict?.requiresUserConfirmation ?? false)
        XCTAssertEqual(titleConflict?.primarySource, .neuStudentPortal)
        XCTAssertEqual(titleConflict?.conflictingSource, .debim)
    }

    // 11. NEU University Connector isolates DEBİM and Portal sessions
    func test_neu_university_connector_isolates_debim_and_portal_sessions() async {
        XCTAssertEqual(moodleConnector.baseURL.host, "debim.neu.edu.tr")
        XCTAssertEqual(portalConnector.baseURL.host, "register.neu.edu.tr")
        XCTAssertNotEqual(moodleConnector.baseURL.host, portalConnector.baseURL.host, "Hosts must remain completely distinct")

        let debimState = await masterConnector.debimState
        let portalState = await masterConnector.studentPortalState
        XCTAssertEqual(debimState, .disconnected)
        XCTAssertEqual(portalState, .disconnected)
    }

    // 12. NEU University Connector tolerates partial sync failure
    func test_neu_university_connector_tolerates_partial_sync_failure() async {
        // Run syncAll with empty local courses; both connectors return their fallback/empty payloads without throwing fatal errors
        let result = await masterConnector.syncAll(localCourses: [])
        XCTAssertNotNil(result.syncTimestamp)
        XCTAssertEqual(result.conflictCount, 0)
    }
}
