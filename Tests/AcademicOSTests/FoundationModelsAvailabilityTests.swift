import XCTest
@testable import AcademicOSKit

/// Mock provider allowing controlled testing of all Apple Foundation Models availability states.
struct MockFoundationModelAvailabilityProvider: FoundationModelAvailabilityProvider {
    let mockStatus: AppleIntelligenceStatus

    func evaluateAvailability() -> AppleIntelligenceStatus {
        return mockStatus
    }
}

/// Validates Foundation Models availability evaluations, unavailable states, and resilient fallback behavior.
final class FoundationModelsAvailabilityTests: XCTestCase {

    func testUnsupportedOSState() async throws {
        let service = AppleIntelligenceAvailabilityService(
            provider: MockFoundationModelAvailabilityProvider(mockStatus: .unsupportedOS)
        )
        let status = service.evaluateAvailability()

        XCTAssertEqual(status, .unsupportedOS)
        XCTAssertFalse(status.isUsable, "Unsupported OS must not report Apple Local AI as usable")

        // Provider must transparently fall back without throwing or crashing
        let provider = AppleLocalAIProvider(availabilityService: service)
        XCTAssertFalse(provider.deviceNeuralEngineAvailable)

        let response = try await provider.generateResponse(for: AIRequest(prompt: "Summarize notes", context: .notes))
        XCTAssertTrue(response.content.contains("AcademicOS Local Engine (Fallback Mode)"))
        XCTAssertEqual(response.modelIdentifier, "academicos-local-template")
    }

    func testDeviceNotEligibleState() async throws {
        let service = AppleIntelligenceAvailabilityService(
            provider: MockFoundationModelAvailabilityProvider(mockStatus: .deviceNotEligible)
        )
        let status = service.evaluateAvailability()

        XCTAssertEqual(status, .deviceNotEligible)
        XCTAssertFalse(status.isUsable)

        let provider = AppleLocalAIProvider(availabilityService: service)
        XCTAssertFalse(provider.deviceNeuralEngineAvailable)

        let response = try await provider.generateResponse(for: AIRequest(prompt: "Generate flashcards", context: .flashcards))
        XCTAssertTrue(response.content.contains("Fallback Mode"))
    }

    func testAppleIntelligenceDisabledInSettingsState() async throws {
        let service = AppleIntelligenceAvailabilityService(
            provider: MockFoundationModelAvailabilityProvider(mockStatus: .appleIntelligenceNotEnabled)
        )
        let status = service.evaluateAvailability()

        XCTAssertEqual(status, .appleIntelligenceNotEnabled)
        XCTAssertFalse(status.isUsable)

        let provider = AppleLocalAIProvider(availabilityService: service)
        XCTAssertFalse(provider.deviceNeuralEngineAvailable)

        let response = try await provider.generateResponse(for: AIRequest(prompt: "Review schedule", context: .studyPlan))
        XCTAssertTrue(response.content.contains("disabled in iOS System Settings"))
    }

    func testModelNotReadyDownloadingState() async throws {
        let service = AppleIntelligenceAvailabilityService(
            provider: MockFoundationModelAvailabilityProvider(mockStatus: .modelNotReady)
        )
        let status = service.evaluateAvailability()

        XCTAssertEqual(status, .modelNotReady)
        XCTAssertFalse(status.isUsable)

        let provider = AppleLocalAIProvider(availabilityService: service)
        XCTAssertFalse(provider.deviceNeuralEngineAvailable)

        let response = try await provider.generateResponse(for: AIRequest(prompt: "Quick review", context: .studyPlan))
        XCTAssertTrue(response.content.contains("downloading or preparing"))
    }

    func testFoundationModelAvailableState() async throws {
        let service = AppleIntelligenceAvailabilityService(
            provider: MockFoundationModelAvailabilityProvider(mockStatus: .available)
        )
        let status = service.evaluateAvailability()

        XCTAssertEqual(status, .available)
        XCTAssertTrue(status.isUsable)

        let provider = AppleLocalAIProvider(availabilityService: service)
        XCTAssertTrue(provider.deviceNeuralEngineAvailable)

        let response = try await provider.generateResponse(for: AIRequest(prompt: "Summarize legal brief", context: .notes))
        XCTAssertTrue(response.content.contains("Apple Foundation Model"))
        XCTAssertTrue(response.content.contains("Apple Neural Engine"))
        XCTAssertEqual(response.providerType, .local)
    }
}
