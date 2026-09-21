import SwiftUI

/// Modern grid/list of academic courses enrolled in by the student with Add Course flow.
public struct CoursesListView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: CoursesViewModel
    @State private var showingAddCourseSheet: Bool = false

    public init() {
        _viewModel = StateObject(wrappedValue: CoursesViewModel(courseRepo: AppContainer.shared.courseRepository))
    }

    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 600), spacing: Spacing.medium)
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                headerSummary

                if viewModel.isLoading && viewModel.courses.isEmpty {
                    ProgressView("Loading Academic Courses...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.xxxLarge)
                } else if viewModel.filteredCourses.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "No Courses Enrolled",
                        message: "Add your first academic course to begin tracking lectures, recording audio, and building isolated AI memory.",
                        actionTitle: "Add Course"
                    ) {
                        showingAddCourseSheet = true
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: Spacing.medium) {
                        ForEach(viewModel.filteredCourses) { course in
                            NavigationLink(destination: CourseDetailView(course: course)) {
                                courseCard(for: course)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xxxLarge)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .searchable(text: $viewModel.searchQuery, prompt: "Search courses, codes, topics")
        .navigationTitle("Courses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddCourseSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.academicPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAddCourseSheet) {
            AddCourseSheet {
                Task { await viewModel.loadCourses() }
            }
        }
        .task {
            await viewModel.loadCourses()
        }
        .refreshable {
            await viewModel.loadCourses()
        }
    }

    private var headerSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.courses.count) Courses Active")
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text("Isolated AI memory active for each course")
                    .font(.commandCaption)
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            StatusBadge("\(viewModel.courses.reduce(0) { $0 + $1.ects }) ECTS TOTAL", style: .indigo)
        }
        .padding(.top, Spacing.xSmall)
    }

    private func courseCard(for course: Course) -> some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    Text(course.code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: course.colorHex))
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.xxxSmall)
                        .background(Color(hex: course.colorHex).opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Text("\(course.ects) ECTS")
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.commandTitle)
                        .foregroundColor(Color.textPrimary)

                    Text(course.department)
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }

                Divider()
                    .background(Color.borderSubtle)

                HStack {
                    if let prof = course.professor {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 12))
                            Text(prof.name)
                                .font(.commandCaption)
                        }
                        .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(course.weeklySchedule)
                            .font(.commandCaption)
                    }
                    .foregroundColor(Color.textTertiary)
                }
            }
        }
    }
}
