import SwiftUI

/// Overview tab inside Course Detail displaying syllabus highlights, instructor info, and AI memory summary.
public struct CourseOverviewSection: View {
    public let course: Course

    public init(course: Course) {
        self.course = course
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // AI Memory Summary Card
            AcademicCard(
                cornerRadius: CornerRadius.medium,
                padding: Spacing.medium,
                borderColor: Color(hex: course.colorHex).opacity(0.3),
                backgroundColor: Color(hex: course.colorHex).opacity(0.06)
            ) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: course.colorHex))

                        Text("COURSE AI MEMORY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: course.colorHex))

                        Spacer()

                        StatusBadge("ISOLATED", style: .cyan)
                    }

                    Text(course.aiMemorySummary)
                        .font(.commandBody)
                        .foregroundColor(Color.textPrimary)
                }
            }

            // Instructor Card
            if let prof = course.professor {
                AcademicCard(
                    cornerRadius: CornerRadius.medium,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("INSTRUCTOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textSecondary)

                        Text("\(prof.title) \(prof.name)")
                            .font(.commandHeadline)
                            .foregroundColor(Color.textPrimary)

                        HStack(spacing: Spacing.large) {
                            if !prof.email.isEmpty {
                                Label(prof.email, systemImage: "envelope")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            if !prof.officeLocation.isEmpty {
                                Label(prof.officeLocation, systemImage: "mappin.and.ellipse")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }
                        }

                        if !prof.officeHours.isEmpty {
                            Text("Office Hours: \(prof.officeHours)")
                                .font(.commandCaption)
                                .foregroundColor(Color.textTertiary)
                        }
                    }
                }
            }

            // Course Schedule Card
            AcademicCard(
                cornerRadius: CornerRadius.medium,
                padding: Spacing.medium,
                backgroundColor: Color(uiColor: .secondarySystemBackground)
            ) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("LOGISTICS & TIMETABLE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.textSecondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lecture Hall")
                                .font(.commandCaption)
                                .foregroundColor(Color.textSecondary)
                            Text(course.lectureRoom)
                                .font(.commandHeadline)
                                .foregroundColor(Color.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Weekly Slot")
                                .font(.commandCaption)
                                .foregroundColor(Color.textSecondary)
                            Text(course.weeklySchedule)
                                .font(.commandHeadline)
                                .foregroundColor(Color.textPrimary)
                        }
                    }
                }
            }
        }
    }
}
