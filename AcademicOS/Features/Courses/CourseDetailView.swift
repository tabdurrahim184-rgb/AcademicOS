import SwiftUI

/// Comprehensive course cockpit containing Overview, Notes, Lectures, Recordings, Documents, Exams, Flashcards, and Course AI.
public struct CourseDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: CourseDetailViewModel

    public init(course: Course) {
        _viewModel = StateObject(wrappedValue: CourseDetailViewModel(
            course: course,
            courseRepo: AppContainer.shared.courseRepository
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Horizontal Segmented Bar for all 8 Sections
            tabBar

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    switch viewModel.selectedTab {
                    case .overview:
                        CourseOverviewSection(course: viewModel.course)
                    case .notes:
                        CourseNotesSection(course: viewModel.course)
                    case .lectures:
                        CourseLecturesSection(course: viewModel.course)
                    case .recordings:
                        CourseRecordingsSection(courseId: viewModel.course.id)
                    case .documents:
                        CourseDocumentsSection(documents: viewModel.documents)
                    case .exams:
                        CourseExamsSection(exams: viewModel.exams)
                    case .flashcards:
                        CourseFlashcardsSection(flashcards: viewModel.flashcards)
                    case .ai:
                        CourseAISection(course: viewModel.course)
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.medium)
                .padding(.bottom, Spacing.xxxLarge)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(viewModel.course.code)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StatusBadge("\(viewModel.course.credits) ECTS", style: .indigo)
            }
        }
        .task {
            await viewModel.loadCourseData()
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xSmall) {
                ForEach(CourseDetailViewModel.CourseTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.xSmall)
                        .foregroundColor(viewModel.selectedTab == tab ? Color.white : Color.textSecondary)
                        .background(
                            viewModel.selectedTab == tab
                            ? Color.academicPrimary
                            : Color(uiColor: .secondarySystemBackground)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
        }
        .background(Color(uiColor: .tertiarySystemBackground).opacity(0.6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.borderSubtle),
            alignment: .bottom
        )
    }
}
