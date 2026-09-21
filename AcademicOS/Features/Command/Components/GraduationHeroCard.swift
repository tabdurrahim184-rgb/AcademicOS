import SwiftUI

/// Command center hero card dynamically calculating countdown and progress from student's target graduation date.
public struct GraduationHeroCard: View {
    public let progress: GraduationProgress
    public let student: StudentProfile?

    public init(progress: GraduationProgress, student: StudentProfile? = nil) {
        self.progress = progress
        self.student = student
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.xLarge,
            padding: Spacing.large,
            borderColor: Color.academicCyan.opacity(0.35),
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // Header with Operation codename & Target Date
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.codename.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Color.academicCyan)
                            .tracking(1.5)

                        Text("Target: " + DateFormatter.localizedString(from: progress.targetGraduationDate, dateStyle: .medium, timeStyle: .none))
                            .font(.commandCaption)
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    StatusBadge("TARGET TRACKING", icon: "scope", style: .cyan)
                }

                Divider().background(Color.borderSubtle)

                // Countdown Metrics Row
                HStack(alignment: .center, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text(progress.countdownFormatted)
                            .font(.metricCountdown)
                            .foregroundColor(Color.textPrimary)

                        if let countdown = student?.graduationCountdown {
                            Text("\(countdown.years)y \(countdown.months)m \(countdown.days)d Remaining")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.academicCyan)
                        } else {
                            Text("Days to Commencement")
                                .font(.commandSubheadline)
                                .foregroundColor(Color.textSecondary)
                        }

                        HStack(spacing: Spacing.xxSmall) {
                            Text("\(progress.completedCredits) / \(progress.totalCreditsRequired) ECTS")
                                .font(.metricMedium)
                                .foregroundColor(Color.academicEmerald)

                            Text("Cleared")
                                .font(.commandCaption)
                                .foregroundColor(Color.textTertiary)
                        }
                        .padding(.top, Spacing.xxSmall)
                    }

                    Spacer()

                    // Circular Progress Indicator
                    ZStack {
                        Circle()
                            .stroke(Color.borderSubtle, lineWidth: 8)
                            .frame(width: 78, height: 78)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(progress.progressPercentage / 100.0, 1.0)))
                            .stroke(
                                LinearGradient(
                                    colors: [Color.academicPrimary, Color.academicCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 78, height: 78)
                            .animation(.easeInOut(duration: 0.8), value: progress.progressPercentage)

                        VStack(spacing: 0) {
                            Text("\(Int(progress.progressPercentage))%")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundColor(Color.textPrimary)

                            Text("Progress")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }

                Divider().background(Color.borderSubtle)

                // Legal / Academic Separation Notice
                HStack(spacing: Spacing.xxSmall) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color.textTertiary)
                    Text("Target graduation date tracked separately from formal university graduation eligibility.")
                        .font(.system(size: 10))
                        .foregroundColor(Color.textTertiary)
                }
            }
        }
    }
}
