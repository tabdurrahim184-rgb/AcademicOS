import SwiftUI

/// Lectures tab inside Course Detail displaying real scheduled lecture sessions with New Lecture creation.
public struct CourseLecturesSection: View {
    @EnvironmentObject private var container: AppContainer
    public let course: Course

    @State private var lectures: [LectureSession] = []
    @State private var showingAddLectureSheet: Bool = false
    @State private var isLoading: Bool = false

    public init(course: Course) {
        self.course = course
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ActionButton(
                "New Lecture Session",
                icon: "plus.circle",
                style: .primary
            ) {
                showingAddLectureSheet = true
            }

            if isLoading && lectures.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.large)
            } else if lectures.isEmpty {
                EmptyStateView(
                    icon: "person.wave.2",
                    title: "No Lecture Sessions Logged",
                    message: "Tap 'New Lecture Session' to add a university class date, agenda, and attendance."
                )
            } else {
                ForEach(lectures) { lecture in
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lecture.topic)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)

                                Text("\(DateFormatter.localizedString(from: lecture.sessionDate, dateStyle: .medium, timeStyle: .none)) • \(lecture.startTime)–\(lecture.endTime)")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)

                                Text(lecture.classroom)
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textTertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                StatusBadge(lecture.attendanceStatus.rawValue.uppercased(), style: attendanceStyle(lecture.attendanceStatus))

                                if lecture.recordingState == .recorded {
                                    StatusBadge("RECORDED", icon: "waveform", style: .cyan)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddLectureSheet) {
            AddLectureSheet(
                courseId: course.id,
                defaultClassroom: course.lectureRoom,
                defaultProfessor: course.professor?.name ?? ""
            ) {
                Task { await loadLectures() }
            }
        }
        .task {
            await loadLectures()
        }
    }

    private func loadLectures() async {
        isLoading = true
        do {
            self.lectures = try await container.lectureRepository.getLectures(forCourseId: course.id)
        } catch {
            print("Lectures load error: \(error)")
        }
        isLoading = false
    }

    private func attendanceStyle(_ status: AttendanceStatus) -> StatusBadge.Style {
        switch status {
        case .present: return .emerald
        case .absent: return .crimson
        case .cancelled: return .amber
        case .upcoming: return .neutral
        }
    }
}
