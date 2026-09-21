import SwiftUI

/// Profile header card showing student identity, university, GPA standing, and semester.
public struct StudentOverviewHeader: View {
    public let profile: StudentProfile
    public let gpa: GPARecord

    public init(profile: StudentProfile, gpa: GPARecord) {
        self.profile = profile
        self.gpa = gpa
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.large,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.academicPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.fullName)
                            .font(.commandTitle)
                            .foregroundColor(Color.textPrimary)

                        Text("\(profile.department) • \(profile.currentSemester)")
                            .font(.commandSubheadline)
                            .foregroundColor(Color.textSecondary)

                        Text(profile.universityName)
                            .font(.commandCaption)
                            .foregroundColor(Color.textTertiary)
                    }

                    Spacer()
                }

                Divider()
                    .background(Color.borderSubtle)

                // GPA & Academic standing statistics
                HStack(spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CUMULATIVE GPA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textTertiary)

                        Text(String(format: "%.2f", gpa.cumulativeGPA))
                            .font(.metricLarge)
                            .foregroundColor(Color.academicEmerald)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SEMESTER GPA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textTertiary)

                        Text(String(format: "%.2f", gpa.currentGPA))
                            .font(.metricLarge)
                            .foregroundColor(Color.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET GPA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textTertiary)

                        Text(String(format: "%.2f", gpa.targetGraduationGPA))
                            .font(.metricLarge)
                            .foregroundColor(Color.academicPrimary)
                    }

                    Spacer()

                    if gpa.honorRoll {
                        StatusBadge("HIGH HONOR", icon: "laurel.leading", style: .emerald)
                    }
                }
            }
        }
    }
}
