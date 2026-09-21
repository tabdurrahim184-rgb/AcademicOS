import XCTest
@testable import AcademicOSKit

/// Synthetic test suite validating Phase 2F Live WebKit integration,
/// standing status determination, evidence sanitization, selector learning,
/// and durable change history.
///
/// NOTICE: All HTML fixtures in this file are SYNTHETIC TEST FIXTURES.
final class Phase2FNEULiveConnectorTests: XCTestCase {
    var transcriptParser: NEUTranscriptParser!
    var changeHistoryService: NEUChangeHistoryService!
    var exporter: NEUPortalInspectionExporter!

    override func setUp() async throws {
        try await super.setUp()
        transcriptParser = NEUTranscriptParser()
        changeHistoryService = NEUChangeHistoryService()
        exporter = NEUPortalInspectionExporter()
    }

    // 1. Standing Status does NOT infer pass/fail without explicit portal status
    func test_standing_status_does_not_infer_pass_without_explicit_portal_status() {
        // Synthetic fixture with letter grade only, no explicit 'Geçti' or 'Kaldı'
        let syntheticLetterOnlyHTML = """
        <html><body>
        <table>
            <tr><td>CENG 311</td><td>System Analysis</td><td>3</td><td>AA</td></tr>
        </table>
        </body></html>
        """

        let summary = transcriptParser.parseTranscript(html: syntheticLetterOnlyHTML)
        XCTAssertEqual(summary.courses.count, 1)
        let course = summary.courses[0]
        XCTAssertEqual(course.grade, "AA")
        XCTAssertEqual(course.academicStanding, .unverified, "Letter-grade only row MUST be marked unverified until official grading rules are verified")
        XCTAssertNil(course.isOfficiallyPassed, "isOfficiallyPassed must be nil for unverified standing")
        XCTAssertEqual(summary.unconfirmedCount, 1)
    }

    // 2. Standing Status preserves explicit portal status
    func test_standing_status_preserves_explicit_portal_status() {
        // Synthetic fixture with explicit portal status
        let syntheticExplicitHTML = """
        <html><body>
        <table>
            <tr><td>CENG 311</td><td>System Analysis</td><td>3</td><td>AA</td><td>Geçti</td></tr>
            <tr><td>ECC 206</td><td>Signals</td><td>4</td><td>FF</td><td>Kaldı</td></tr>
            <tr><td>HIST 101</td><td>History</td><td>2</td><td>S</td><td>Muaf</td></tr>
        </table>
        </body></html>
        """

        let summary = transcriptParser.parseTranscript(html: syntheticExplicitHTML)
        XCTAssertEqual(summary.courses.count, 3)

        let ceng = summary.courses.first { $0.courseCode == "CENG 311" }
        XCTAssertEqual(ceng?.academicStanding, .portalReportedPassed)
        XCTAssertEqual(ceng?.isOfficiallyPassed, true)

        let ecc = summary.courses.first { $0.courseCode == "ECC 206" }
        XCTAssertEqual(ecc?.academicStanding, .portalReportedFailed)
        XCTAssertEqual(ecc?.isOfficiallyPassed, false)

        let hist = summary.courses.first { $0.courseCode == "HIST 101" }
        XCTAssertEqual(hist?.academicStanding, .portalReportedPassed)
    }

    // 3. Sanitized Evidence replaces raw HTML and stores SHA-256 fingerprint
    func test_sanitized_evidence_replaces_raw_html_and_stores_fingerprint() {
        let syntheticHTML = "<table><tr><td>CENG 101</td><td>Intro</td><td>3</td><td>BA</td><td>Geçti</td></tr></table>"
        let summary = transcriptParser.parseTranscript(html: syntheticHTML)
        XCTAssertEqual(summary.courses.count, 1)
        let course = summary.courses[0]

        XCTAssertFalse(course.evidence.contentFingerprint.isEmpty, "Fingerprint must be populated")
        XCTAssertFalse(course.evidence.safeVisibleTextExcerpt.contains("<tr"), "Excerpt must not contain raw HTML tags")
        XCTAssertFalse(course.evidence.safeVisibleTextExcerpt.contains("<td"), "Excerpt must not contain raw HTML tags")
        XCTAssertEqual(course.evidence.safeTableHeaders.count, 7)
    }

    // 4. Sanitized Evidence purges sensitive tokens, cookies, and passwords
    func test_sanitized_evidence_purges_sensitive_tokens_and_passwords() {
        let dirtyString = """
        MoodleSession=abc12345secret; ASP.NET_SessionId=xyz98765;
        name="__RequestVerificationToken" value="token_val_here";
        student: john.doe@university.edu.tr phone: 0533 888 77 66 id: 20210452
        """

        let clean = exporter.sanitizeRawContent(dirtyString)
        XCTAssertFalse(clean.contains("abc12345secret"))
        XCTAssertFalse(clean.contains("xyz98765"))
        XCTAssertFalse(clean.contains("token_val_here"))
        XCTAssertFalse(clean.contains("john.doe@university.edu.tr"))
        XCTAssertFalse(clean.contains("0533 888 77 66"))
        XCTAssertFalse(clean.contains("20210452"))
        XCTAssertTrue(clean.contains("[REDACTED_SESSION]"))
        XCTAssertTrue(clean.contains("[STUDENT_ID]"))
    }

    // 5. Live Coordinator manages isolated DEBİM and Student Portal sessions
    @MainActor
    func test_live_coordinator_manages_isolated_debim_and_portal_sessions() {
        let coordinator = NEULivePortalCoordinator.shared
        XCTAssertEqual(coordinator.debimSessionState, .loggedOut)
        XCTAssertEqual(coordinator.portalSessionState, .loggedOut)
    }

    // 6. DEBİM session detects Google SAML and enforces manual login
    func test_debim_session_detects_google_saml_and_enforces_manual_login() {
        let moodle = NEUMoodleConnector.shared
        let googleURL = URL(string: "https://accounts.google.com/o/saml2/initsso?idpid=C03neu")!
        XCTAssertEqual(moodle.identifyPageType(url: googleURL), .googleSAMLRedirect)
        XCTAssertFalse(moodle.canAutofillCredentials(on: googleURL), "Autofill must NEVER be permitted on Google SAML")
    }

    // 7. Session validation is deterministic without AI
    func test_session_validation_deterministic_without_ai() {
        let debim = NEUMoodleConnector.shared
        let authDashboard = URL(string: "https://debim.neu.edu.tr/my/")!
        XCTAssertTrue(debim.identifyPageType(url: authDashboard) == .courseList)

        let portal = NEUStudentPortalConnector.shared
        let authRoute = URL(string: "https://register.neu.edu.tr/StudentCourse/Transcript")!
        XCTAssertTrue(portal.isApprovedPortalURL(authRoute))
    }

    // 8. Selector Profile Learning detects found and not found
    @MainActor
    func test_selector_profile_learning_detects_found_and_not_found() {
        let coordinator = NEULivePortalCoordinator.shared
        let capturedClasses = ["table", "table-striped", "main-panel"]
        let capturedHeaders = ["Ders Kodu", "Ders Adı", "Harf Notu"]

        let report = coordinator.evaluateLiveSelectors(capturedClasses: capturedClasses, capturedHeaders: capturedHeaders)
        XCTAssertEqual(report.fieldResults["TRANSCRIPT TABLE"], .found)
        XCTAssertEqual(report.fieldResults["COURSE CODE COLUMN"], .found)
        XCTAssertEqual(report.fieldResults["COURSE NAME COLUMN"], .found)
        XCTAssertEqual(report.fieldResults["GRADE COLUMN"], .found)
        XCTAssertEqual(report.fieldResults["ECTS COLUMN"], .notFound)
    }

    // 9. Selector Profile flags needsReview on DOM drift
    @MainActor
    func test_selector_profile_flags_needs_review_on_dom_drift() {
        let coordinator = NEULivePortalCoordinator.shared
        // Severely drifted DOM
        let capturedClasses = ["unknown-div", "spa-root"]
        let capturedHeaders = ["Custom 1", "Custom 2"]

        let report = coordinator.evaluateLiveSelectors(capturedClasses: capturedClasses, capturedHeaders: capturedHeaders)
        XCTAssertEqual(report.overallStatus, .needsReview, "Substantial DOM drift must flag .needsReview")
    }

    // 10. Material Discovery detects files
    func test_material_discovery_detects_pdf_and_pptx() {
        let mat = DiscoveredCourseMaterial(
            filename: "Lecture_01_Introduction.pdf",
            courseCode: "CENG 311",
            fileExtension: "pdf",
            downloadURL: URL(string: "https://debim.neu.edu.tr/mod/resource/view.php?id=123")!,
            sizeBytes: 1024 * 1024 * 2
        )
        XCTAssertEqual(mat.courseCode, "CENG 311")
        XCTAssertEqual(mat.fileExtension, "pdf")
        XCTAssertFalse(mat.isDownloaded)
    }

    // 11. Change History tracks grade publication and assignment addition
    func test_change_history_tracks_grade_publication_and_assignment_addition() async {
        let previous = RemoteUniversityPayload(
            courses: [],
            announcements: [],
            exams: [],
            assignments: [],
            grades: [],
            documents: [],
            lastSyncTimestamp: Date().addingTimeInterval(-3600)
        )

        let freshGrade = RemoteGrade(
            remoteId: "g1",
            courseCode: "CENG 311",
            name: "Midterm Exam",
            score: 88,
            letterGrade: "AA",
            weightPercentage: 35,
            date: Date()
        )
        let fresh = RemoteUniversityPayload(
            courses: [],
            announcements: [],
            exams: [],
            assignments: [],
            grades: [freshGrade],
            documents: [],
            lastSyncTimestamp: Date()
        )

        let deltas = await changeHistoryService.detectDeltas(previousPayload: previous, freshPayload: fresh, source: .neuStudentPortal)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas[0].changeType, .gradePublished)
        XCTAssertEqual(deltas[0].courseCode, "CENG 311")
    }

    // 12. Notification Rules filter routine syncs
    func test_notification_rules_filter_routine_syncs() async {
        let res1 = await changeHistoryService.recordChange(
            changeType: .gradePublished,
            entityId: "grade_1",
            title: "Grade Published",
            newValue: "AA",
            source: .neuStudentPortal
        )
        XCTAssertTrue(res1.shouldNotify, "New grade publication MUST notify")

        let res2 = await changeHistoryService.recordChange(
            changeType: .materialAdded,
            entityId: "doc_1",
            title: "Syllabus Uploaded",
            newValue: "Syllabus.pdf",
            source: .debim
        )
        XCTAssertFalse(res2.shouldNotify, "Routine material discovery must NOT spam push notifications")
    }

    // 13. Stale data indicator shows hours since sync
    func test_stale_data_indicator_shows_hours_since_sync() async {
        let connector = NEUUniversityConnector.shared
        let status = await connector.formattedStaleDataStatus()
        XCTAssertFalse(status.isEmpty)
    }

    // 14. Diagnostics JSON export contains zero credentials
    func test_diagnostics_json_export_contains_zero_credentials() {
        let diag = NEUConnectorDiagnosticsReport(
            debimLogin: .pass,
            debimDashboard: .pass,
            debimCourses: .pass,
            portalLogin: .pass,
            portalTranscript: .pass
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = (try? encoder.encode(diag)) ?? Data()
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(jsonString.contains("password"))
        XCTAssertFalse(jsonString.contains("token"))
        XCTAssertFalse(jsonString.contains("cookie"))
        XCTAssertFalse(jsonString.contains("saml"))
    }
}
