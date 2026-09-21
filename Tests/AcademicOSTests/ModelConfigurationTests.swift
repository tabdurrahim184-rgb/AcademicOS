import XCTest
import Foundation
@testable import AcademicOS

final class ModelConfigurationTests: XCTestCase {
    var service: ModelConfigurationService!

    override func setUp() {
        super.setUp()
        service = ModelConfigurationService.shared
        service.resetToDefault()
    }

    override func tearDown() {
        service.resetToDefault()
        super.tearDown()
    }

    func testDefaultModelIsGemini38Flash() {
        let activeModel = service.getActiveModelName()
        XCTAssertEqual(activeModel, "gemini-3.8-flash", "The production default model must be gemini-3.8-flash.")
    }

    func testSafeFreeTierModelsAccepted() {
        service.setActiveModelName("gemini-2.5-flash")
        XCTAssertEqual(service.getActiveModelName(), "gemini-2.5-flash", "Whitelisted free-tier models must be accepted.")
    }

    func testPaidProModelsRejected() {
        // Attempting to set a paid Pro model that requires billing
        service.setActiveModelName("gemini-1.5-pro")
        XCTAssertEqual(service.getActiveModelName(), "gemini-3.8-flash", "Pro models requiring billing must be rejected and safe default retained.")

        service.setActiveModelName("gemini-ultra")
        XCTAssertEqual(service.getActiveModelName(), "gemini-3.8-flash", "Ultra models requiring billing must be rejected.")
    }

    func testFreeTierEligibilityChecker() {
        XCTAssertTrue(service.isFreeTierEligible(model: "gemini-3.8-flash"))
        XCTAssertTrue(service.isFreeTierEligible(model: "gemini-2.5-flash"))
        XCTAssertFalse(service.isFreeTierEligible(model: "gemini-flash-latest"), "Undocumented alias must not be whitelisted.")
        XCTAssertFalse(service.isFreeTierEligible(model: "gemini-1.5-pro"))
        XCTAssertFalse(service.isFreeTierEligible(model: "gpt-4o"))
    }

    func testRemoteConfigFallbackWhenUnavailable() {
        // In the absence of Firebase Remote Config, safe local default is used
        let model = service.getActiveModelName()
        XCTAssertFalse(model.isEmpty)
        XCTAssertEqual(model, AIModelConfiguration.defaultModelIdentifier)
    }
}
