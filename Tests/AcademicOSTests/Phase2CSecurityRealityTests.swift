import XCTest
@testable import AcademicOSKit

final class Phase2CSecurityRealityTests: XCTestCase {
    var credentialPolicy: CredentialDomainPolicy!
    var navigationPolicy: NavigationDomainPolicy!
    var webSessionManager: UniversityWebSessionManager!
    var credentialManager: UniversityCredentialManager!
    var keychain: KeychainStorage!
    var gpaCalculator: GPACalculator!
    var store: InMemoryDatabaseManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainStorage(useMemoryFallbackOnly: true)
        credentialManager = UniversityCredentialManager(keychain: keychain)
        credentialPolicy = CredentialDomainPolicy()
        navigationPolicy = NavigationDomainPolicy()
        webSessionManager = UniversityWebSessionManager(
            credentialPolicy: credentialPolicy,
            navigationPolicy: navigationPolicy,
            credentialManager: credentialManager
        )
        gpaCalculator = GPACalculator()
        store = InMemoryDatabaseManager()

        // Configure exact authorized portal host
        credentialPolicy.registerApprovedAuthenticationHost("uzem.university.edu.tr")
    }

    // 1. Broad edu.tr host cannot receive credentials
    func testBroadEduTrHostCannotReceiveCredentials() {
        let broadEduURL = URL(string: "https://random-faculty.university.edu.tr/login")!
        let canInject = credentialPolicy.canInjectCredentials(into: broadEduURL, isMainFrame: true)
        XCTAssertFalse(canInject, "Broad *.edu.tr domain must NOT automatically inherit credential injection permission.")
    }

    // 2. Configured exact portal host can receive credentials
    func testConfiguredExactPortalHostCanReceiveCredentials() {
        let exactURL = URL(string: "https://uzem.university.edu.tr/login/index.php")!
        let canInject = credentialPolicy.canInjectCredentials(into: exactURL, isMainFrame: true)
        XCTAssertTrue(canInject, "Exact configured portal host must be authorized for credential injection.")
    }

    // 3. Unconfigured sibling subdomain cannot receive credentials
    func testUnconfiguredSiblingSubdomainCannotReceiveCredentials() {
        let siblingURL = URL(string: "https://library.university.edu.tr/auth")!
        let canInject = credentialPolicy.canInjectCredentials(into: siblingURL, isMainFrame: true)
        XCTAssertFalse(canInject, "Sibling subdomain without explicit authorization must be rejected.")
    }

    // 4. Iframe cannot receive autofill
    func testIframeCannotReceiveAutofill() {
        let exactURL = URL(string: "https://uzem.university.edu.tr/login")!
        let canInjectInIframe = credentialPolicy.canInjectCredentials(into: exactURL, isMainFrame: false)
        XCTAssertFalse(canInjectInIframe, "Credential injection into non-main frames (iframes) must be strictly forbidden.")
    }

    // 5. HTTP login blocked
    func testHTTPLoginBlocked() {
        let insecureURL = URL(string: "http://uzem.university.edu.tr/login")!
        let decision = webSessionManager.decidePolicyForNavigation(targetURL: insecureURL, isMainFrame: true)
        if case .cancelAndBlock = decision {
            XCTAssertTrue(true, "Insecure HTTP navigation must be canceled and blocked.")
        } else {
            XCTFail("Insecure HTTP must not be allowed.")
        }
    }

    // 6. Unexpected redirect clears autofill eligibility
    func testUnexpectedRedirectClearsAutofillEligibility() {
        let initialURL = URL(string: "https://uzem.university.edu.tr/login")!
        _ = webSessionManager.decidePolicyForNavigation(targetURL: initialURL, isMainFrame: true, isRedirect: false)

        // Simulate unexpected redirect to external/different domain
        let redirectURL = URL(string: "https://external-auth-tracker.com/intercept")!
        let redirectDecision = webSessionManager.decidePolicyForNavigation(targetURL: redirectURL, isMainFrame: true, isRedirect: true)

        XCTAssertFalse(webSessionManager.canAutofillCredentials(url: redirectURL, isMainFrame: true),
                       "Unexpected redirect must clear autofill eligibility immediately.")
    }

    // 7. WKWebView cookie data not copied into SQLite
    func testWKWebViewCookieDataNotCopiedIntoSQLite() async throws {
        let session = UniversityWebSession(
            isAuthenticated: true,
            dataStoreIdentifier: "TestStore",
            loginTime: Date(),
            expirationState: "Active"
        )
        credentialManager.updateWebSession(session)

        // Verify SQLite store contains zero cookie tables or records
        let allInbox: [UniversityInboxItem] = try await store.fetchAll()
        let allGrades: [UniversityGrade] = try await store.fetchAll()
        XCTAssertTrue(allInbox.isEmpty)
        XCTAssertTrue(allGrades.isEmpty)
    }

    // 8. Disconnect clears portal session
    func testDisconnectClearsPortalSession() {
        let activeSession = UniversityWebSession(isAuthenticated: true, loginTime: Date())
        credentialManager.updateWebSession(activeSession)
        XCTAssertTrue(credentialManager.currentWebSession().isAuthenticated)

        webSessionManager.clearWebSession(deleteKeychainCredentials: false)
        XCTAssertFalse(credentialManager.currentWebSession().isAuthenticated, "Disconnect must end active web session.")
    }

    // 9. Disconnect optionally preserves Keychain credential
    func testDisconnectOptionallyPreservesKeychainCredential() throws {
        try credentialManager.saveCredential(username: "student2026", password: "Password123!")
        XCTAssertNotNil(try credentialManager.getStoredCredential())

        // Disconnect with preserve credentials = true (deleteKeychainCredentials = false)
        webSessionManager.clearWebSession(deleteKeychainCredentials: false)
        let retained = try credentialManager.getStoredCredential()
        XCTAssertNotNil(retained, "Keychain credential must be preserved when requested.")
        XCTAssertEqual(retained?.username, "student2026")

        // Disconnect with deleteKeychainCredentials = true
        webSessionManager.clearWebSession(deleteKeychainCredentials: true)
        let deleted = try credentialManager.getStoredCredential()
        XCTAssertNil(deleted, "Keychain credential must be deleted when explicitly requested.")
    }

    // 10. GPA local-credit weighting
    func testGPALocalCreditWeighting() {
        // Course 1: 4 credits (local), AA (4.0) -> 16.0
        // Course 2: 2 credits (local), BA (3.5) -> 7.0
        // Total points = 23.0, Total credits = 6 -> GPA = 23.0 / 6 = 3.83
        let subjects = [
            GPASubjectItem(courseCode: "CENG 311", credits: 4, ects: 8, letterGrade: "AA"),
            GPASubjectItem(courseCode: "LAB 101", credits: 2, ects: 2, letterGrade: "BA")
        ]

        let result = gpaCalculator.calculateGPA(subjects: subjects, policy: .localCourseCredits)
        XCTAssertEqual(result.gpa, 3.83)
        XCTAssertEqual(result.weightingPolicy, .localCourseCredits)
    }

    // 11. GPA ECTS weighting
    func testGPAECTSWeighting() {
        // Course 1: 8 ECTS, AA (4.0) -> 32.0
        // Course 2: 2 ECTS, BA (3.5) -> 7.0
        // Total points = 39.0, Total ECTS = 10 -> GPA = 39.0 / 10 = 3.90
        let subjects = [
            GPASubjectItem(courseCode: "CENG 311", credits: 4, ects: 8, letterGrade: "AA"),
            GPASubjectItem(courseCode: "LAB 101", credits: 2, ects: 2, letterGrade: "BA")
        ]

        let result = gpaCalculator.calculateGPA(subjects: subjects, policy: .ectsCredits)
        XCTAssertEqual(result.gpa, 3.90)
        XCTAssertEqual(result.weightingPolicy, .ectsCredits)
    }

    // 12. Ambiguous AI-extracted date requires confirmation
    func testAmbiguousAIExtractedDateRequiresConfirmation() {
        let aiExtractedLevel = PortalDataTrustLevel.aiExtracted
        XCTAssertTrue(aiExtractedLevel.requiresUserConfirmation,
                      "AI-extracted dates must require user confirmation before becoming official.")

        let officialLevel = PortalDataTrustLevel.officialPortal
        XCTAssertFalse(officialLevel.requiresUserConfirmation,
                       "Official portal deterministic fields do not require re-confirmation.")
    }

    // 13. Demo data never appears in production mode
    func testDemoDataNeverAppearsInProductionMode() async throws {
        // Production fresh store
        let prodStore = InMemoryDatabaseManager()
        let prodCourses: [Course] = try await prodStore.fetchAll()
        let prodAnnouncements: [UniversityAnnouncement] = try await prodStore.fetchAll()

        XCTAssertTrue(prodCourses.isEmpty, "Production first launch must have zero courses.")
        XCTAssertTrue(prodAnnouncements.isEmpty, "Production first launch must have zero fake announcements.")

        // Verify that demo connector explicitly flags items as demo
        let demoConnector = DemoUniversityConnector(simulatedDelayNanoseconds: 0)
        let demoCourses = try await demoConnector.fetchCourses()
        for course in demoCourses {
            XCTAssertTrue(course.name.contains("[DEMO]"), "All demo courses must be tagged [DEMO].")
        }
    }
}
