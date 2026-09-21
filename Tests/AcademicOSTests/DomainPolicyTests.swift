import XCTest
@testable import AcademicOSKit

final class DomainPolicyTests: XCTestCase {
    var policyService: DomainPolicyService!

    override func setUp() {
        super.setUp()
        let navPolicy = NavigationDomainPolicy(customSafeDomains: ["sis.custom-univ.org"])
        policyService = DomainPolicyService(navigationPolicy: navPolicy)
    }

    func testAuthorizedEducationalDomains() {
        let validEduTr = URL(string: "https://uzem.university.edu.tr/login")!
        XCTAssertTrue(policyService.isAuthorized(url: validEduTr))

        let validSubdomain = URL(string: "https://obs.boun.edu.tr/grades")!
        XCTAssertTrue(policyService.isAuthorized(url: validSubdomain))

        let validCustom = URL(string: "https://sis.custom-univ.org/api/v1")!
        XCTAssertTrue(policyService.isAuthorized(url: validCustom))

        let validLocalhost = URL(string: "http://localhost:5050/api")!
        XCTAssertTrue(policyService.isAuthorized(url: validLocalhost))
    }

    func testRejectsUnauthorizedExternalDomains() {
        let phishingURL = URL(string: "https://malicious-site.com/steal-creds")!
        XCTAssertFalse(policyService.isAuthorized(url: phishingURL))

        let trackingURL = URL(string: "https://google-analytics.com/collect")!
        XCTAssertFalse(policyService.isAuthorized(url: trackingURL))

        // Insecure HTTP on non-localhost must be rejected
        let insecureEdu = URL(string: "http://uzem.university.edu.tr/login")!
        XCTAssertFalse(policyService.isAuthorized(url: insecureEdu))
    }
}
