import XCTest
import Combine
import Foundation
@testable import AcademicOS

final class AIRouterTests: XCTestCase {
    var networkMonitor: NetworkMonitor!
    var onlineProvider: GeminiOnlineAIProvider!
    var localProvider: AppleLocalAIProvider!
    var router: AIRouter!

    override func setUp() {
        super.setUp()
        networkMonitor = NetworkMonitor(initialStatus: .online)
        onlineProvider = GeminiOnlineAIProvider()
        localProvider = AppleLocalAIProvider()
        router = AIRouter(
            onlineProvider: onlineProvider,
            localProvider: localProvider,
            networkMonitor: networkMonitor
        )
    }

    func testRouterUsesOnlineWhenConnected() {
        router.setRoutingMode(.automatic)
        networkMonitor.simulateStatusChange(to: .online)
        XCTAssertEqual(router.activeProviderType, .online)
        XCTAssertTrue(router.isRoutingToCloud)
    }

    func testRouterSwitchesToLocalWhenOffline() {
        networkMonitor.simulateStatusChange(to: .offline)
        XCTAssertEqual(router.activeProviderType, .local)
        XCTAssertFalse(router.isRoutingToCloud)
    }

    func testLocalOnlyModeNeverCallsOnline() {
        networkMonitor.simulateStatusChange(to: .online)
        router.setRoutingMode(.localOnly)

        let request = AIRequest(prompt: "Explain Bourdieu's Habitus concept")
        let provider = router.route(for: request, task: nil)

        XCTAssertEqual(provider.providerType, .local)
        XCTAssertFalse(router.isRoutingToCloud)
    }

    func testCourseCloudPrivacyOffForcesLocal() {
        networkMonitor.simulateStatusChange(to: .online)
        router.setRoutingMode(.automatic)

        let courseId = UUID()
        router.setCourseCloudAllowed(courseId: courseId, allowed: false)

        let request = AIRequest(prompt: "Summarize this lecture", courseId: courseId)
        let provider = router.route(for: request, task: nil)

        XCTAssertEqual(provider.providerType, .local, "Course with cloud privacy OFF must never route to cloud.")
    }

    func testSensitiveTaskNeverSentToCloud() {
        networkMonitor.simulateStatusChange(to: .online)
        router.setRoutingMode(.onlinePreferred)

        let sensitiveTask = AITask(
            type: .summarizeLecture,
            privacyLevel: .sensitive
        )
        let request = AIRequest(prompt: "Analyze student record")
        let provider = router.route(for: request, task: sensitiveTask)

        XCTAssertEqual(provider.providerType, .local, "Sensitive tasks must strictly route to local AI.")
    }

    func testSensitiveContentInPromptSanitizedToLocal() {
        networkMonitor.simulateStatusChange(to: .online)
        router.setRoutingMode(.onlinePreferred)

        let request = AIRequest(prompt: "My password: SuperSecretPassword123")
        let provider = router.route(for: request, task: nil)

        XCTAssertEqual(provider.providerType, .local, "Prompts containing passwords must be intercepted and routed to local.")
        XCTAssertTrue(AIPrivacySanitizer.containsSensitiveContent(request.prompt))
    }

    func testRouterExecutesSuccessfullyOffline() async throws {
        networkMonitor.simulateStatusChange(to: .offline)

        let request = AIRequest(prompt: "Summarize Chapter 1 of Communication Law")
        let response = try await router.execute(request: request)

        XCTAssertEqual(response.providerType, .local)
        XCTAssertFalse(response.content.isEmpty)
    }
}
