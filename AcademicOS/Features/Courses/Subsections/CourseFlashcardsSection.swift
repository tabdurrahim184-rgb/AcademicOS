import SwiftUI

/// Flashcards tab inside Course Detail displaying active recall study decks.
public struct CourseFlashcardsSection: View {
    public let flashcards: [Flashcard]

    public init(flashcards: [Flashcard]) {
        self.flashcards = flashcards
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if flashcards.isEmpty {
                EmptyStateView(
                    icon: "rectangle.stack",
                    title: "No Flashcards Generated",
                    message: "Generate active recall flashcards directly from lecture notes using the Study Agent.",
                    actionTitle: "Generate Flashcards"
                ) {
                    // Flashcard gen action
                }
            } else {
                ForEach(flashcards) { card in
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            HStack {
                                Text(card.deckTitle.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.academicPrimary)

                                Spacer()

                                StatusBadge("INTERVAL \(card.intervalDays)D", style: .neutral)
                            }

                            Text("Q: \(card.question)")
                                .font(.commandHeadline)
                                .foregroundColor(Color.textPrimary)

                            Text("A: \(card.answer)")
                                .font(.commandBody)
                                .foregroundColor(Color.textSecondary)
                                .padding(.top, Spacing.xxSmall)
                        }
                    }
                }
            }
        }
    }
}
