import XCTest
import Foundation
@testable import AcademicOS

final class MyMaterialsOnlyGroundingTests: XCTestCase {
    var router: AIRouter!
    var courseAgent: CourseAgent!
    let courseAId = UUID()
    let courseBId = UUID()

    override func setUp() {
        super.setUp()
        let networkMonitor = NetworkMonitor(initialStatus: .online)
        router = AIRouter(
            onlineProvider: GeminiOnlineAIProvider(),
            localProvider: AppleLocalAIProvider(),
            networkMonitor: networkMonitor
        )
        courseAgent = CourseAgent(router: router)
    }

    func testMyMaterialsOnlyReturnsExplicitMissingWhenNoMaterialsStored() async throws {
        // Empty context with no notes, transcripts, or memories
        let emptyContext: [String: String] = [
            "course_name": "İletişim Sosyolojisi",
            "course_code": "COMM101",
            "course_id": courseAId.uuidString
        ]

        let result = try await courseAgent.queryCourse(
            courseId: courseAId,
            courseName: "İletişim Sosyolojisi",
            question: "Bourdieu'nün kültürel sermaye teorisi nedir?",
            context: emptyContext,
            myMaterialsOnly: true
        )

        XCTAssertTrue(
            result.content.contains("The answer is not present in the materials stored for this course") ||
            result.content.contains("bulunmamaktadır"),
            "When no materials exist, My Materials Only mode must strictly return the required missing message without hallucinating."
        )
        XCTAssertFalse(result.isGrounded)
    }

    func testMyMaterialsOnlyPermitsAnswersWhenMaterialsExist() async throws {
        let populatedContext: [String: String] = [
            "course_name": "Medya Hukuku",
            "course_code": "LAW202",
            "course_id": courseBId.uuidString,
            "course_notes": "Note: Basın Özgürlüğü İlkeleri\nAnayasa madde 28: Basın hürdür, sansür edilemez.",
            "course_memory": "[EXAM HINT]: Hoca Anayasa 28'in istisnalarına dikkat çekti."
        ]

        let result = try await courseAgent.queryCourse(
            courseId: courseBId,
            courseName: "Medya Hukuku",
            question: "Basın hürriyeti hangi maddede düzenlenmiştir?",
            context: populatedContext,
            myMaterialsOnly: true
        )

        XCTAssertFalse(result.content.isEmpty)
    }

    func testGeneralAIModeDistinguishesMaterialsFromExplanation() {
        let systemPrompt = PromptCatalog.courseChatSystemInstruction(courseName: "Siyaset Bilimi", myMaterialsOnly: false)
        XCTAssertTrue(systemPrompt.contains("[FROM YOUR MATERIALS / PROFESSOR SAID]") || systemPrompt.contains("[Ders Materyali]"))
        XCTAssertTrue(systemPrompt.contains("[AI EXPLANATION]") || systemPrompt.contains("[Ek Akademik Açıklama]"))
    }
}
