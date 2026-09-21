import XCTest
import Foundation
@testable import AcademicOS

final class ExamAgentQuestionTypesTests: XCTestCase {
    var router: AIRouter!
    var examAgent: ExamAgent!
    let testCourseId = UUID()

    override func setUp() {
        super.setUp()
        let networkMonitor = NetworkMonitor(initialStatus: .online)
        router = AIRouter(
            onlineProvider: GeminiOnlineAIProvider(),
            localProvider: AppleLocalAIProvider(),
            networkMonitor: networkMonitor
        )
        examAgent = ExamAgent(router: router)
    }

    func testAllQuestionFormatsSupported() async throws {
        let formats: [ExamQuestionFormat] = [
            .mcq,
            .trueFalse,
            .shortAnswer,
            .essay,
            .conceptComparison,
            .oralQuestions
        ]

        for format in formats {
            let questions = try await examAgent.generatePracticeQuestions(
                courseName: "Kamu Diplomasisi",
                emphasisItems: [],
                courseNotesSnippet: "Kamu diplomasisi yumuşak güç araçlarını kullanır.",
                format: format,
                questionCount: 3,
                courseId: testCourseId
            )

            XCTAssertFalse(questions.isEmpty, "ExamAgent must successfully produce output for \(format.rawValue).")
            XCTAssertFalse(questions.contains("kesin çıkacak soru"), "Exam questions must never be labeled as guaranteed.")
        }
    }

    func testAllowedLabelsDefinition() {
        let labels = ExamQuestionAllowedLabel.allCases
        XCTAssertEqual(labels.count, 3)
        XCTAssertTrue(labels.contains(.practiceQuestion))
        XCTAssertTrue(labels.contains(.professorEmphasizedTopic))
        XCTAssertTrue(labels.contains(.importantReviewTopic))
    }
}
