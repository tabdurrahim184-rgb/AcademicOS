import Foundation

/// Coordinates AI flashcard proposal batches with Accept / Edit / Reject workflow.
public final class FlashcardGenerationService: @unchecked Sendable {
    private let flashcardRepo: FlashcardRepositoryProtocol
    private let aiRouter: AIRouterProtocol

    public init(
        flashcardRepo: FlashcardRepositoryProtocol,
        aiRouter: AIRouterProtocol
    ) {
        self.flashcardRepo = flashcardRepo
        self.aiRouter = aiRouter
    }

    /// Generates a proposed batch of flashcards from lecture text or emphasis items.
    /// Clamps count between 1 and 15 to prevent uncontrolled generation.
    public func proposeFlashcards(
        courseId: UUID,
        sourceText: String,
        count: Int = 5
    ) async throws -> [FlashcardProposalItem] {
        let clampedCount = min(max(count, 1), 15)

        let prompt = """
        DERS İÇERİĞİ:
        \(sourceText.prefix(1500))

        Lütfen bu içerikten \(clampedCount) adet yüksek verimli çalışma kartı (flashcard) soru-cevap ikilisi çıkar:
        Türler: definition, concept, comparison, example, trueFalse.
        Her kart için net bir soru ve kısa, kesin bir cevap oluştur.
        """

        let request = AIRequest(
            prompt: prompt,
            systemInstruction: "Sen aktif hatırlama (active recall) ve flashcard uzmanısın. Net ve sınav odaklı sorular üret.",
            courseId: courseId,
            requiresStructuredOutput: true
        )

        let response = try await aiRouter.execute(request: request)

        // Parse lines or generate structured proposal items
        var proposals: [FlashcardProposalItem] = []
        let lines = response.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        for (i, line) in lines.prefix(clampedCount * 2).enumerated() where i % 2 == 0 {
            let question = line.replacingOccurrences(of: "Soru:", with: "").trimmingCharacters(in: .whitespaces)
            let answer = (i + 1 < lines.count) ? lines[i + 1].replacingOccurrences(of: "Cevap:", with: "").trimmingCharacters(in: .whitespaces) : "Key concept"

            if !question.isEmpty {
                proposals.append(FlashcardProposalItem(
                    frontQuestion: question,
                    backAnswer: answer,
                    type: "concept",
                    sourceReference: "AI Generated Suggestion",
                    status: .pending
                ))
            }
        }

        if proposals.isEmpty {
            // Safe fallback proposal
            proposals.append(FlashcardProposalItem(
                frontQuestion: "Bu dersin temel tezi nedir?",
                backAnswer: "Ders içeriğinde vurgulanan ana kavramsal çerçeve ve metot.",
                type: "concept",
                status: .pending
            ))
        }

        return Array(proposals.prefix(clampedCount))
    }

    /// User Action: Accept a proposed flashcard and commit it to the SQLite study deck.
    @discardableResult
    public func acceptFlashcard(
        proposal: FlashcardProposalItem,
        courseId: UUID,
        deckTitle: String = "Lecture Cards"
    ) async throws -> Flashcard {
        var acceptedProposal = proposal
        acceptedProposal.status = .accepted

        let card = Flashcard(
            courseId: courseId,
            deckTitle: deckTitle,
            question: acceptedProposal.frontQuestion,
            answer: acceptedProposal.backAnswer,
            difficulty: 3,
            reviewCount: 0,
            nextReviewDate: Date(),
            easeFactor: 2.5,
            intervalDays: 1
        )
        try await flashcardRepo.saveFlashcard(card)
        return card
    }

    /// User Action: Edit a proposed flashcard before committing it to SQLite.
    @discardableResult
    public func editAndAcceptFlashcard(
        proposal: FlashcardProposalItem,
        editedQuestion: String,
        editedAnswer: String,
        courseId: UUID,
        deckTitle: String = "Lecture Cards"
    ) async throws -> Flashcard {
        var editedProposal = proposal
        editedProposal.frontQuestion = editedQuestion
        editedProposal.backAnswer = editedAnswer
        editedProposal.status = .edited

        let card = Flashcard(
            courseId: courseId,
            deckTitle: deckTitle,
            question: editedQuestion,
            answer: editedAnswer,
            difficulty: 3,
            reviewCount: 0,
            nextReviewDate: Date(),
            easeFactor: 2.5,
            intervalDays: 1
        )
        try await flashcardRepo.saveFlashcard(card)
        return card
    }

    /// User Action: Reject a proposed flashcard.
    /// Strictly ensures the card is NEVER saved to the database.
    public func rejectFlashcard(proposal: inout FlashcardProposalItem) {
        proposal.status = .rejected
        // Explicitly does NOT call flashcardRepo.saveFlashcard()
    }
}
