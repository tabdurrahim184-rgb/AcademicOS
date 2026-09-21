import XCTest
import Foundation
@testable import AcademicOS

final class MasteryAndQuizTests: XCTestCase {
    var localStore: LocalStoreProtocol!
    var masteryRepo: MasteryRepositoryProtocol!
    let courseId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        masteryRepo = DatabaseMasteryRepository(localStore: localStore)
    }

    func testDeterministicMasteryCalculation() {
        var mastery = AcademicMastery(courseId: courseId, topic: "Anayasa Hukuku İlkeleri")

        // 1st attempt: Correct with 0.8 confidence -> 1/1 * 0.8 + 0.8 * 0.2 = 0.8 + 0.16 = 0.96
        mastery.recordAttempt(isCorrect: true, userConfidence: 0.8)
        XCTAssertEqual(mastery.attempts, 1)
        XCTAssertEqual(mastery.correctAnswers, 1)
        XCTAssertEqual(mastery.incorrectAnswers, 0)
        XCTAssertEqual(mastery.masteryScore, 0.96, accuracy: 0.01)

        // 2nd attempt: Incorrect with 0.5 confidence -> 1/2 * 0.8 + 0.5 * 0.2 = 0.4 + 0.1 = 0.50
        mastery.recordAttempt(isCorrect: false, userConfidence: 0.5)
        XCTAssertEqual(mastery.attempts, 2)
        XCTAssertEqual(mastery.correctAnswers, 1)
        XCTAssertEqual(mastery.incorrectAnswers, 1)
        XCTAssertEqual(mastery.masteryScore, 0.50, accuracy: 0.01)
    }

    func testQuizServiceUpdatesMasteryInRepository() async throws {
        let online = GeminiOnlineAIProvider()
        let local = AppleLocalAIProvider()
        let router = AIRouter(onlineProvider: online, localProvider: local, networkMonitor: NetworkMonitor.shared)
        let quizService = InteractiveQuizService(masteryRepo: masteryRepo, aiRouter: router)

        let topic = "Pozitivizm ve Hukuk Felsefesi"
        try await quizService.recordAnswer(
            courseId: courseId,
            topic: topic,
            isCorrect: true,
            userConfidence: 0.9
        )

        let storedMastery = try await masteryRepo.getMastery(forCourseId: courseId, topic: topic)
        XCTAssertNotNil(storedMastery)
        XCTAssertEqual(storedMastery?.attempts, 1)
        XCTAssertEqual(storedMastery?.correctAnswers, 1)
        XCTAssertGreaterThan(storedMastery?.masteryScore ?? 0.0, 0.8)
    }
}
