import SwiftUI

/// Strategic academic calendar view showing month overview and upcoming exams, assignments, projects, and classes.
public struct AcademicCalendarView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: AcademicCalendarViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: AcademicCalendarViewModel(
            calendarRepo: AppContainer.shared.calendarRepository
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Month Overview
                MonthCalendarOverview(
                    selectedDate: $viewModel.selectedDate,
                    events: viewModel.events
                )

                // Filter Pill Bar
                categoryFilterBar

                // Events List
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView("Loading Calendar...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.xxxLarge)
                } else if viewModel.filteredEvents.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Events Scheduled",
                        message: "No academic events found for the selected category."
                    )
                } else {
                    VStack(spacing: Spacing.small) {
                        ForEach(viewModel.filteredEvents) { event in
                            EventScheduleRow(event: event)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xxxLarge)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Calendar")
        .task {
            await viewModel.loadCalendarEvents()
        }
        .refreshable {
            await viewModel.loadCalendarEvents()
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xSmall) {
                ForEach(CalendarUnifiedEvent.EventCategory.allCases) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedCategory = category
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, Spacing.medium)
                            .padding(.vertical, Spacing.xSmall)
                            .foregroundColor(viewModel.selectedCategory == category ? Color.white : Color.textSecondary)
                            .background(
                                viewModel.selectedCategory == category
                                ? Color.academicPrimary
                                : Color(uiColor: .secondarySystemBackground)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
