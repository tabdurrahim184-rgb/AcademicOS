import SwiftUI

/// Exams tab inside Course Detail displaying midterms, finals, weights, and grade targets.
public struct CourseExamsSection: View {
    public let exams: [Exam]

    public init(exams: [Exam]) {
        self.exams = exams
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if exams.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.gearshape",
                    title: "No Exams Logged",
                    message: "Course examinations and target grade distributions will be tracked here."
                )
            } else {
                ForEach(exams) { exam in
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        borderColor: Color.academicCrimson.opacity(0.3),
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Text(exam.title)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)

                                Spacer()

                                StatusBadge("\(exam.weightPercentage)% WEIGHT", style: .crimson)
                            }

                            HStack {
                                Label(dateFormatter.string(from: exam.examDate), systemImage: "calendar")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)

                                Spacer()

                                Label(exam.room, systemImage: "mappin")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            if !exam.topicsCovered.isEmpty {
                                Divider()
                                    .background(Color.borderSubtle)

                                Text("Scope: " + exam.topicsCovered.joined(separator: " • "))
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
