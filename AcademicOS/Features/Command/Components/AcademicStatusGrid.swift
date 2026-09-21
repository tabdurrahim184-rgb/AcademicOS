import SwiftUI

/// 2x2 grid representing the real-time academic pulse.
public struct AcademicStatusGrid: View {
    public let activeCourses: Int
    public let upcomingExams: Int
    public let assignmentsDue: Int
    public let tasksToday: Int

    public init(
        activeCourses: Int,
        upcomingExams: Int,
        assignmentsDue: Int,
        tasksToday: Int
    ) {
        self.activeCourses = activeCourses
        self.upcomingExams = upcomingExams
        self.assignmentsDue = assignmentsDue
        self.tasksToday = tasksToday
    }

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.small),
        GridItem(.flexible(), spacing: Spacing.small)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("ACADEMIC STATUS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.textSecondary)
                .tracking(1.0)

            LazyVGrid(columns: columns, spacing: Spacing.small) {
                MetricBadge(
                    label: "Active Courses",
                    value: "\(activeCourses)",
                    icon: "books.vertical.fill",
                    accentColor: Color.academicPrimary
                )

                MetricBadge(
                    label: "Upcoming Exams",
                    value: "\(upcomingExams)",
                    icon: "doc.badge.gearshape.fill",
                    accentColor: Color.academicCrimson
                )

                MetricBadge(
                    label: "Assignment Due",
                    value: "\(assignmentsDue)",
                    icon: "clock.badge.exclamationmark.fill",
                    accentColor: Color.academicAmber
                )

                MetricBadge(
                    label: "Tasks Today",
                    value: "\(tasksToday)",
                    icon: "checklist.checked",
                    accentColor: Color.academicEmerald
                )
            }
        }
    }
}
