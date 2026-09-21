import SwiftUI

/// Primary command center dashboard for AcademicOS backed by real SQLite databases.
public struct CommandDashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: CommandViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: CommandViewModel(
            studentRepo: AppContainer.shared.studentRepository,
            courseRepo: AppContainer.shared.courseRepository,
            taskRepo: AppContainer.shared.taskRepository,
            examRepo: AppContainer.shared.examRepository,
            gradRepo: AppContainer.shared.graduationRepository
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Tactical Command Header
                commandHeader

                // Operation Graduation Hero Card
                if let progress = viewModel.graduationProgress {
                    GraduationHeroCard(progress: progress, student: viewModel.studentProfile)
                }

                // University Portal Connection Card
                NavigationLink(destination: UniversityPortalView()) {
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.statusSuccess)
                                        .frame(width: 7, height: 7)
                                    Text("UNIVERSITY PORTAL")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color.statusSuccess)
                                }
                                Text("Campus Sync, Grades & Alerts")
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }

                // Dynamic Academic Status Grid
                AcademicStatusGrid(
                    activeCourses: viewModel.coursesCount,
                    upcomingExams: viewModel.examsCount,
                    assignmentsDue: viewModel.assignmentsCount,
                    tasksToday: viewModel.tasksCount
                )

                // Today's Missions
                if !viewModel.todaysMissions.isEmpty {
                    MissionTimelineView(
                        missions: viewModel.todaysMissions,
                        onToggle: { id in
                            Task {
                                await viewModel.toggleMissionCompletion(id: id)
                            }
                        }
                    )
                }

                // Upcoming Strategic Targets (Exams, Assignments, Project)
                UpcomingEventsSection(
                    exams: viewModel.upcomingExams,
                    assignments: viewModel.upcomingAssignments
                )
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xxxLarge)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: Spacing.xxSmall) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.academicPrimary)

                    Text("ACADEMIC COMMAND CENTER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .task {
            await viewModel.loadDashboardData()
        }
        .refreshable {
            await viewModel.loadDashboardData()
        }
    }

    // Top Command Header with dynamic AI badge
    private var commandHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.studentProfile?.fullName.isEmpty == false ? viewModel.studentProfile!.fullName : "AcademicOS")
                    .font(.commandDisplay)
                    .foregroundColor(Color.textPrimary)

                Text(viewModel.studentProfile?.universityName.isEmpty == false ? "\(viewModel.studentProfile!.universityName) • Command" : "Academic Command Center")
                    .font(.commandSubheadline)
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            // Dynamic AI status badge: LOCAL AI or CLOUD AI
            if container.activeAIProviderType == .online {
                StatusBadge("CLOUD AI", icon: "cloud.fill", style: .indigo)
            } else {
                StatusBadge("LOCAL AI", icon: "cpu", style: .emerald)
            }
        }
        .padding(.top, Spacing.xSmall)
    }
}
