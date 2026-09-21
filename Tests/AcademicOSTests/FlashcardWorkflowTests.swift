import XCTest
import Foundation
@testable import AcademicOS

final class FlashcardWorkflowTests: XCTestCase {
    var store: InMemoryDatabaseManager!
    var flashcardRepo: DatabaseFlashcardRepository!
    var router: AIRouter!
    var service: FlashcardGenerationService!
    let testCourseId = UUID()

    override func setUp() {
        super.setUp()
        store = InMemoryDatabaseManager()
        flashcardRepo = DatabaseFlashcardRepository(localStore: store)
        let networkMonitor = NetworkMonitor(initialStatus: .online)
        router = AIRouter(
            onlineProvider: GeminiOnlineAIProvider(),
            localProvider: AppleLocalAIProvider(),
            networkMonitor: networkMonitor
        )
        service = FlashcardGenerationService(
            flashcardRepo: flashcardRepo,
            aiRouter: router
        )
    }

    func testProposalCountIsClampedToSafeLimit() async throws {
        // Requesting an excessive number of flashcards (e.g. 100) must be clamped to max 15
        let proposals = try await service.proposeFlashcards(
            courseId: testCourseId,
            sourceText: "Hukukun temel ilkeleri: Kanun önünde eşitlik, adalet ve hakkaniyet.",
            count: 100
        )

        XCTAssertLessThanOrEqual(proposals.count, 15, "Flashcard generation count must be clamped to prevent mass creation.")
        XCTAssertGreaterThanOrEqual(proposals.count, 1)
        for proposal in proposals {
            XCTAssertEqual(proposal.status, .pending, "Initial proposals must have status .pending.")
        }
    }

    func testAcceptFlashcardCommitsToDeck() async throws {
        let proposal = FlashcardProposalItem(
            frontQuestion: "Normlar hiyerarşisinin en tepesinde ne yer alır?",
            backAnswer: "Anayasa",
            type: "definition"
        )

        let savedCard = try await service.acceptFlashcard(
            proposal: proposal,
            courseId: testCourseId,
            deckTitle: "Hukuk Başlangıcı"
        )

        XCTAssertEqual(savedCard.question, "Normlar hiyerarşisinin en tepesinde ne yer alır?")
        XCTAssertEqual(savedCard.answer, "Anayasa")

        let storedCards = try await flashcardRepo.getFlashcards(forCourseId: testCourseId)
        XCTAssertEqual(storedCards.count, 1, "Accepted flashcard must be committed to SQLite repository.")
        XCTAssertEqual(storedCards.first?.question, proposal.frontQuestion)
    }

    func testEditAndAcceptFlashcardCommitsEditedContent() async throws {
        let proposal = FlashcardProposalItem(
            frontQuestion: "Kusursuz sorumluluk nedir?",
            backAnswer: "Sorumluluktur.",
            type: "concept"
        )

        let editedQuestion = "Hukukta kusursuz (objektif) sorumluluk nedir?"
        let editedAnswer = "Kişinin kusuru bulunmasa dahi kanunun öngördüğü tehlike veya özen yükümlülüğünün ihlali sonucu doğan zararı tazmin borcudur."

        let savedCard = try await service.editAndAcceptFlashcard(
            proposal: proposal,
            editedQuestion: editedQuestion,
            editedAnswer: editedAnswer,
            courseId: testCourseId,
            deckTitle: "Borçlar Hukuku"
        )

        XCTAssertEqual(savedCard.question, editedQuestion)
        XCTAssertEqual(savedCard.answer, editedAnswer)

        let storedCards = try await flashcardRepo.getFlashcards(forCourseId: testCourseId)
        XCTAssertEqual(storedCards.count, 1)
        XCTAssertEqual(storedCards.first?.question, editedQuestion)
        XCTAssertEqual(storedCards.first?.answer, editedAnswer)
    }

    func testRejectFlashcardNeverSavedToRepository() async throws {
        var proposal = FlashcardProposalItem(
            frontQuestion: "Önemsiz bir yan detay sorusu?",
            backAnswer: "Gereksiz bilgi",
            type: "concept"
        )

        service.rejectFlashcard(proposal: &proposal)

        XCTAssertEqual(proposal.status, .rejected, "Rejected proposal must have status .rejected.")

        let storedCards = try await flashcardRepo.getFlashcards(forCourseId: testCourseId)
        XCTAssertTrue(storedCards.isEmpty, "Rejected flashcard must NEVER be written to the database.")
    }
}
