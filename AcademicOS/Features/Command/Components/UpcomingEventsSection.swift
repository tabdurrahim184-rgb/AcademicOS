import SwiftUI

/// Section displaying upcoming Exams, Assignments, and Capstone Project milestones.
public struct UpcomingEventsSection: View {
    public let exams: [Exam]
    public let assignments: [Assignment]

    public init(exams: [Exam], assignments: [Assignment]) {
        self.exams = exams
        self.assignments = assignments
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("UPCOMING STRATEGIC TARGETS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.textSecondary)
                .tracking(1.0)

            VStack(spacing: Spacing.small) {
                // Exam item
                if let exam = exams.first {
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        HStack(spacing: Spacing.medium) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.academicCrimson)
                                .frame(width: 4, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: Spacing.xxSmall) {
                                    Text("EXAM")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(Color.academicCrimson)

                                    Text("• \(exam.room)")
                                        .font(.commandCaption)
                                        .foregroundColor(Color.textSecondary)
                                }

                                Text(exam.title)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)
                            }

                            Spacer()

                            Text(dateFormatter.string(from: exam.examDate))
                                .font(.commandCaption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }

                // Assignment item
                if let assignment = assignments.first {
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        HStack(spacing: Spacing.medium) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.academicAmber)
                                .frame(width: 4, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: Spacing.xxSmall) {
                                    Text("ASSIGNMENT")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(Color.academicAmber)

                                    Text("• Weight 20%")
                                        .font(.commandCaption)
                                        .foregroundColor(Color.textSecondary)
                                }

                                Text(assignment.title)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)
                            }

                            Spacer()

                            StatusBadge("DUE SOON", style: .amber)
                        }
                    }
                }

                // Capstone Project item
                AcademicCard(
                    cornerRadius: CornerRadius.medium,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    HStack(spacing: Spacing.medium) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.academicCyan)
                            .frame(width: 4, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xxSmall) {
                                Text("PROJECT")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(Color.academicCyan)

                                Text("• Capstone Milestone")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Text("Senior Thesis Fieldwork Verification")
                                .font(.commandHeadline)
                                .foregroundColor(Color.textPrimary)
                        }

                        Spacer()

                        StatusBadge("IN PROGRESS", style: .cyan)
                    }
                }
            }
        }
    }
}
