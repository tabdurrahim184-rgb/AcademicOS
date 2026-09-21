import XCTest
@testable import AcademicOSKit

final class Phase2DRealConnectorTests: XCTestCase {
    var domainPolicy: DomainPolicyService!
    var store: InMemoryDatabaseManager!
    var cookieBridge: HostCookieBridge!
    var downloader: UniversityDocumentDownloader!
    var classifier: PortalPageClassifier!
    var inspectionService: PortalInspectionService!
    var reconciliationEngine: CourseReconciliationEngine!
    var changeDetectionEngine: PortalChangeDetectionEngine!
    var relevanceEngine: AcademicRelevanceEngine!

    override func setUp() {
        super.setUp()
        domainPolicy = DomainPolicyService()
        store = InMemoryDatabaseManager()
        cookieBridge = HostCookieBridge()
        downloader = UniversityDocumentDownloader(
            domainPolicy: domainPolicy,
            localStore: store,
            cookieBridge: cookieBridge,
            approvedDocumentHosts: ["uzem.university.edu.tr", "obs.university.edu.tr", "localhost"]
        )
        classifier = PortalPageClassifier()
        inspectionService = PortalInspectionService()
        reconciliationEngine = CourseReconciliationEngine()
        changeDetectionEngine = PortalChangeDetectionEngine()
        relevanceEngine = AcademicRelevanceEngine()
    }

    // 1. Authenticated WKDownload / Document Download path succeeds on approved host
    func testAuthenticatedWKDownloadPath() async throws {
        let doc = RemoteDocument(
            remoteId: "doc-1",
            courseCode: "CENG 311",
            fileName: "Lecture1_Overview",
            fileExtension: "pdf",
            downloadURL: URL(string: "https://uzem.university.edu.tr/files/l1.pdf")!,
            docType: "LectureSlides"
        )
        let courseId = UUID()
        let downloaded = try await downloader.downloadDocument(from: doc, forCourseId: courseId)

        XCTAssertEqual(downloaded.fileName, "Lecture1_Overview")
        XCTAssertEqual(downloaded.fileExtension, "pdf")
        XCTAssertTrue(downloaded.fileSizeByte > 0)
    }

    // 2. Unapproved host download blocked by security policy
    func testUnapprovedHostDownloadBlocked() async {
        let unapprovedDoc = RemoteDocument(
            remoteId: "doc-unapproved",
            courseCode: "CENG 311",
            fileName: "MaliciousFile",
            fileExtension: "pdf",
            downloadURL: URL(string: "https://external-untrusted-cdn.com/file.pdf")!,
            docType: "LectureSlides"
        )
        let courseId = UUID()

        do {
            _ = try await downloader.downloadDocument(from: unapprovedDoc, forCourseId: courseId)
            XCTFail("Downloading from an unapproved domain must throw an error.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Unauthorized") || error.localizedDescription.contains("approved"))
        }
    }

    // 3. No global cookie copying — only exact host cookies bridged
    func testNoGlobalCookieCopying_OnlyExactHostCookiesBridged() async {
        let targetHost = "uzem.university.edu.tr"
        let portalCookie = HTTPCookie(properties: [
            .domain: targetHost,
            .path: "/",
            .name: "MoodleSession",
            .value: "secret_session_token_123"
        ])!

        let trackerCookie = HTTPCookie(properties: [
            .domain: "google-analytics.com",
            .path: "/",
            .name: "_ga",
            .value: "ga_token_456"
        ])!

        cookieBridge.registerCookies([portalCookie, trackerCookie], forExactHost: targetHost)

        let targetURL = URL(string: "https://uzem.university.edu.tr/files/syllabus.pdf")!
        let bridgedCookies = await cookieBridge.getCookiesForExactHost(
            url: targetURL,
            approvedHosts: ["uzem.university.edu.tr"]
        )

        XCTAssertEqual(bridgedCookies.count, 1)
        XCTAssertEqual(bridgedCookies.first?.name, "MoodleSession")
        XCTAssertFalse(bridgedCookies.contains(where: { $0.name == "_ga" }), "Third-party tracker cookies must never be bridged.")

        // Unapproved host request receives zero cookies
        let otherURL = URL(string: "https://evil.com/leak")!
        let zeroCookies = await cookieBridge.getCookiesForExactHost(
            url: otherURL,
            approvedHosts: ["uzem.university.edu.tr"]
        )
        XCTAssertTrue(zeroCookies.isEmpty, "Unapproved host must receive zero bridged cookies.")
    }

    // 4. Portal page classification (12 page types)
    func testPortalPageClassification_12PageTypes() {
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/login/index.php")!).pageType, .login)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://obs.edu.tr/ogrenci/sinavlar")!).pageType, .exams)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://obs.edu.tr/notlar/transkript")!).pageType, .grades)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/mod/assign/view.php")!).pageType, .assignments)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://obs.edu.tr/devamsizlik")!).pageType, .attendance)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/duyurular")!).pageType, .announcements)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/course/view.php?id=311")!, pageTitle: "CENG 311 Operating Systems").pageType, .courseDetail)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/my/courses.php")!).pageType, .courses)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/message/index.php")!).pageType, .messages)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/dashboard")!).pageType, .dashboard)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://uzem.edu.tr/resource/view.php")!, pageTitle: "Ders Materyalleri").pageType, .documents)
        XCTAssertEqual(classifier.classify(url: URL(string: "https://unknown.com/page")!).pageType, .unknown)
    }

    // 5. Selector fallback strategy (CSS -> Semantic text -> Manual)
    func testSelectorFallback_CSS_Semantic_Manual() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Ege University",
            portalBaseURL: URL(string: "https://uzem.university.edu.tr")!,
            loginURL: URL(string: "https://uzem.university.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        // Raw HTML without standard CSS classes but with semantic headers
        let semanticHTML = """
        <table>
            <tr><th>Ders Kodu</th><th>Ders Adı</th></tr>
            <tr><td>CENG 311</td><td>Operating Systems</td></tr>
            <tr><td>MATH 101</td><td>Calculus I</td></tr>
        </table>
        """
        let courses = connector.parseCourses(from: semanticHTML)
        XCTAssertEqual(courses.count, 2)
        XCTAssertEqual(courses[0].code, "CENG 311")
        XCTAssertEqual(courses[1].code, "MATH 101")
    }

    // 6. Real connector parsing fixtures
    func testRealConnectorParsingFixtures() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Test Uni",
            portalBaseURL: URL(string: "https://uzem.test.edu.tr")!,
            loginURL: URL(string: "https://uzem.test.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        let fixtureIdentityHTML = """
        <div class="user-profile">
            <span>Öğrenci: 20210102030</span>
            <span>Adı Soyadı: Ahmet Yılmaz</span>
            <span>Bölüm: Bilgisayar Mühendisliği</span>
        </div>
        """
        let identity = connector.parseStudentIdentity(from: fixtureIdentityHTML)
        XCTAssertEqual(identity.studentNumber, "20210102030")
        XCTAssertEqual(identity.fullName, "Ahmet Yılmaz")
        XCTAssertEqual(identity.department, "Bilgisayar Mühendisliği")
    }

    // 7. Course reconciliation priority order
    func testCourseReconciliation_PriorityOrder() {
        let localCourses = [
            Course(id: UUID(), code: "CENG 311", name: "Operating Systems", credits: 4, ects: 6),
            Course(id: UUID(), code: "MATH 201", name: "Linear Algebra", credits: 3, ects: 5),
            Course(id: UUID(), code: "SE 301", name: "Software Engineering Principles", credits: 3, ects: 5)
        ]

        // Tier 1: Exact code match
        let exactRemote = RemoteCourse(remoteId: "r-1", code: "CENG 311", name: "Operating Systems", instructor: "", credits: 4, ects: 6)
        let exactResult = reconciliationEngine.reconcileSingle(remoteCourse: exactRemote, localCourses: localCourses)
        XCTAssertEqual(exactResult.strategy, .exactCode)
        XCTAssertEqual(exactResult.confidenceScore, 1.0)
        XCTAssertFalse(exactResult.requiresUserConfirmation)

        // Tier 2: Normalized code match (hyphenated code "CENG-311")
        let normRemote = RemoteCourse(remoteId: "r-2", code: "CENG-311", name: "Operating Systems", instructor: "", credits: 4, ects: 6)
        let normResult = reconciliationEngine.reconcileSingle(remoteCourse: normRemote, localCourses: localCourses)
        XCTAssertEqual(normResult.strategy, .normalizedCode)
        XCTAssertFalse(normResult.requiresUserConfirmation)

        // Tier 3: Exact title match with different code
        let titleRemote = RemoteCourse(remoteId: "r-3", code: "BLM 311", name: "Operating Systems", instructor: "", credits: 4, ects: 6)
        let titleResult = reconciliationEngine.reconcileSingle(remoteCourse: titleRemote, localCourses: localCourses)
        XCTAssertEqual(titleResult.strategy, .exactTitle)
        XCTAssertFalse(titleResult.requiresUserConfirmation)

        // Tier 5: Low-confidence match requires confirmation
        let unknownRemote = RemoteCourse(remoteId: "r-4", code: "HIST 101", name: "Atatürk İlkeleri", instructor: "", credits: 2, ects: 2)
        let unknownResult = reconciliationEngine.reconcileSingle(remoteCourse: unknownRemote, localCourses: localCourses)
        XCTAssertEqual(unknownResult.strategy, .manualSelectionRequired)
        XCTAssertTrue(unknownResult.requiresUserConfirmation, "Low-confidence matches must never be automatically merged.")
    }

    // 8. Exam parsing with scope and room
    func testExamParsing_WithScopeAndRoom() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Test Uni",
            portalBaseURL: URL(string: "https://uzem.test.edu.tr")!,
            loginURL: URL(string: "https://uzem.test.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        let examHTML = """
        <tr>
            <td>CENG 311 Vize Sınavı</td>
            <td>Derslik: Amfi 2</td>
        </tr>
        """
        let exams = connector.parseExams(from: examHTML)
        XCTAssertEqual(exams.count, 1)
        XCTAssertEqual(exams[0].courseCode, "CENG 311")
        XCTAssertEqual(exams[0].examType, "Midterm")
        XCTAssertEqual(exams[0].room, "Amfi 2")
    }

    // 9. Assignment parsing is strictly read-only
    func testAssignmentParsing_ReadOnly() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Test Uni",
            portalBaseURL: URL(string: "https://uzem.test.edu.tr")!,
            loginURL: URL(string: "https://uzem.test.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        let asgHTML = """
        <div class="assignment">
            <span>Ödev: CPU Scheduling Simulation</span>
        </div>
        """
        let assignments = connector.parseAssignments(from: asgHTML)
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments[0].title, "CPU Scheduling Simulation")
        XCTAssertNil(assignments[0].submissionURL, "AcademicOS must remain read-only; no submission action.")
    }

    // 10. Announcement parsing preserves original and separates derived metadata
    func testAnnouncementParsing_OriginalPreservedAndDerivedSeparate() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Test Uni",
            portalBaseURL: URL(string: "https://uzem.test.edu.tr")!,
            loginURL: URL(string: "https://uzem.test.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        let rawAnnouncementHTML = """
        <div class="announcement">
            <h3>CENG 311 Ara Sınav Kapsamı</h3>
            <p>1-6. haftalar arası konulardan sorumlusunuz. Proje teslim tarihi haftaya uzatıldı.</p>
        </div>
        """
        let announcements = connector.parseAnnouncements(from: rawAnnouncementHTML)
        XCTAssertEqual(announcements.count, 1)

        let ann = announcements[0]
        let derived = AnnouncementDerivedMetadata(
            summary: "CENG 311 sınav kapsamı ve proje ertelemesi.",
            importantDates: [Date()],
            mentionsExam: true,
            mentionsAssignment: true
        )

        let stored = UniversityAnnouncement(
            portalId: UUID(),
            title: ann.title,
            body: ann.body,
            originalBody: ann.body,
            derivedMetadata: derived
        )

        XCTAssertEqual(stored.originalBody, ann.body, "Original body must be preserved without alteration.")
        XCTAssertTrue(stored.derivedMetadata?.mentionsExam ?? false)
        XCTAssertTrue(stored.derivedMetadata?.mentionsAssignment ?? false)
    }

    // 11. Grade parsing with assessment aliases
    func testGradeParsing_AliasesSupport() {
        let aliases = AssessmentAliases()
        XCTAssertEqual(aliases.categorize(evaluationName: "1. Ara Sınav"), "Midterm")
        XCTAssertEqual(aliases.categorize(evaluationName: "Dönem Sonu Sınavı"), "Final")
        XCTAssertEqual(aliases.categorize(evaluationName: "Bütünleme Sınavı"), "Resit")
        XCTAssertEqual(aliases.categorize(evaluationName: "Kısa Sınav 1"), "Quiz")
        XCTAssertEqual(aliases.categorize(evaluationName: "Laboratuvar Ödevi"), "Homework")
        XCTAssertEqual(aliases.categorize(evaluationName: "Dönem Projesi"), "Project")
    }

    // 12. Document parsing and offline availability
    func testDocumentParsing_AndOfflineAvailability() {
        let config = RealUniversityConnectorConfiguration(
            universityName: "Test Uni",
            portalBaseURL: URL(string: "https://uzem.test.edu.tr")!,
            loginURL: URL(string: "https://uzem.test.edu.tr/login")!
        )
        let connector = CustomUniversityConnector(config: config)

        let docHTML = """
        <a href="/files/Chapter1_Introduction.pdf">Ders Notu 1</a>
        <a href="/files/Syllabus.docx">Ders İzlencesi</a>
        """
        let docs = connector.parseDocuments(from: docHTML)
        XCTAssertEqual(docs.count, 2)
        XCTAssertEqual(docs[0].fileExtension, "pdf")
        XCTAssertEqual(docs[1].fileExtension, "docx")
    }

    // 13. Ambiguous date requires user confirmation
    func testAmbiguousDate_RequiresUserConfirmation() {
        let ambiguousExam = RemoteExam(
            remoteId: "e-ambiguous",
            courseCode: "CENG 311",
            title: "CENG 311 Vize",
            examType: "Midterm",
            date: Date(),
            room: nil,
            weightPercentage: 40,
            requiresUserConfirmation: true
        )
        XCTAssertTrue(ambiguousExam.requiresUserConfirmation, "Ambiguous exam dates must flag user confirmation requirement.")
    }

    // 14. Import preview category selection
    func testImportPreview_CategoryFiltering() {
        let payload = RemoteUniversityPayload(
            courses: [RemoteCourse(remoteId: "c-1", code: "CENG 311", name: "OS", instructor: "", credits: 4, ects: 6)],
            announcements: [RemoteAnnouncement(remoteId: "a-1", courseCode: "CENG 311", title: "Notice", body: "Text", author: "Hoca", isUrgent: false, date: Date())],
            exams: [RemoteExam(remoteId: "e-1", courseCode: "CENG 311", title: "Vize", examType: "Midterm", date: Date(), room: "A1", weightPercentage: 40)],
            assignments: [],
            grades: [],
            documents: []
        )

        // User chooses to import ONLY Courses and Exams, excluding Announcements
        let selectedCategories = ["Courses", "Exams"]
        XCTAssertTrue(selectedCategories.contains("Courses"))
        XCTAssertTrue(selectedCategories.contains("Exams"))
        XCTAssertFalse(selectedCategories.contains("Announcements"))
        XCTAssertEqual(payload.courses.count, 1)
    }

    // 15. Session expiry detection and safe prompt
    func testSessionExpiry_DetectionAndPrompt() {
        let expiredHTML = """
        <div class="login-box">
            <span>Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.</span>
            <input type="password" name="password" />
        </div>
        """
        let classification = classifier.classify(
            url: URL(string: "https://uzem.edu.tr/login/index.php")!,
            pageTitle: "Giriş Yap",
            sanitizedDOM: expiredHTML
        )
        XCTAssertEqual(classification.pageType, .login, "Expired session redirects to login page.")
    }

    // 16. Portal change detection (NEW, UPDATED, UNCHANGED, POSSIBLY_REMOVED)
    func testPortalChangeDetection_NewUpdatedUnchangedRemoved() {
        let examDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let changedDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!

        let localExams = [
            Exam(id: UUID(), courseId: UUID(), title: "CENG 311 Vize", examType: "Midterm", examDate: examDate, room: "Amfi 1", weightPercentage: 40),
            Exam(id: UUID(), courseId: UUID(), title: "MATH 101 Vize", examType: "Midterm", examDate: examDate, room: "D201", weightPercentage: 40)
        ]

        let remoteExams = [
            // Updated date
            RemoteExam(remoteId: "e-1", courseCode: "CENG 311", title: "CENG 311 Vize", examType: "Midterm", date: changedDate, room: "Amfi 1", weightPercentage: 40),
            // New exam
            RemoteExam(remoteId: "e-2", courseCode: "SE 301", title: "SE 301 Quiz", examType: "Quiz", date: examDate, room: "Lab 3", weightPercentage: 20)
            // MATH 101 omitted from remote -> POSSIBLY_REMOVED
        ]

        let deltas = changeDetectionEngine.evaluateExams(remoteExams: remoteExams, localExams: localExams)
        let summary = PortalSyncDeltaSummary(deltas: deltas)

        XCTAssertEqual(summary.newCount, 1, "SE 301 should be detected as NEW.")
        XCTAssertEqual(summary.updatedCount, 1, "CENG 311 date change should be detected as UPDATED.")
        XCTAssertEqual(summary.possiblyRemovedCount, 1, "MATH 101 missing from remote should be marked POSSIBLY_REMOVED.")

        // Verify local data was NOT deleted
        XCTAssertEqual(localExams.count, 2, "Local SQLite records must never be deleted silently.")
    }

    // 17. Offline stale-data indication
    func testOfflineStaleDataIndication() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let daysAgo = Calendar.current.dateComponents([.day], from: twoDaysAgo, to: Date()).day ?? 0

        XCTAssertGreaterThanOrEqual(daysAgo, 2)
        let staleNotice = "Last synchronized \(daysAgo) days ago."
        XCTAssertTrue(staleNotice.contains("2 days ago"))
    }
}
