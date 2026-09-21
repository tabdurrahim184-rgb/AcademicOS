import SwiftUI

/// Component displaying an individual course grade and letter evaluation.
public struct UniversityGradeCard: View {
    public let grade: UniversityGrade

    public init(grade: UniversityGrade) {
        self.grade = grade
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack {
                    Text(grade.courseCode)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.academicPrimary)

                    Spacer()

                    if let letter = grade.letterGrade {
                        Text(letter)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(letterBadgeColor(letter).opacity(0.15))
                            .foregroundColor(letterBadgeColor(letter))
                            .clipShape(Capsule())
                    }
                }

                Text(grade.evaluationName)
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                HStack {
                    Text("Score: \(Int(grade.score)) / \(Int(grade.maxScore))")
                        .font(.commandSubheadline)
                        .foregroundColor(Color.textSecondary)

                    Spacer()

                    Text("Weight: \(Int(grade.weightPercentage))%")
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }

                ProgressView(value: grade.percentage, total: 100.0)
                    .tint(letterBadgeColor(grade.letterGrade ?? "CC"))
            }
        }
    }

    private func letterBadgeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "AA", "BA": return Color.statusSuccess
        case "BB", "CB": return Color.academicCyan
        case "CC", "DC": return Color.statusWarning
        default: return Color.statusCritical
        }
    }
}
