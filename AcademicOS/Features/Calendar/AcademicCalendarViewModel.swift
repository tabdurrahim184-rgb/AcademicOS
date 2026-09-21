import SwiftUI
import Combine

/// Calendar event wrapper uniting exams, assignments, classes, and study sessions into a single timeline.
public struct CalendarUnifiedEvent: Identifiable, Sendable {
    public enum EventCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case classes = "Classes"
        case exams = "Exams"
        case assignments = "Assignments"
        case study = "Study"

        public var id: String { rawValue }
    }

    public let id: UUID
    public let title: String
    public let subtitle: String
    public let date: Date
    public let category: EventCategory
    public let color: Color

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        date: Date,
        category: EventCategory,
        color: Color
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.category = category
        self.color = color
    }
}

/// State coordinator for Academic Calendar.
@MainActor
public final class AcademicCalendarViewModel: ObservableObject {
    @Published public var selectedCategory: CalendarUnifiedEvent.EventCategory = .all
    @Published public var selectedDate: Date = Date()
    @Published public var events: [CalendarUnifiedEvent] = []
    @Published public var isLoading: Bool = false

    private let calendarRepo: CalendarRepositoryProtocol

    public init(calendarRepo: CalendarRepositoryProtocol) {
        self.calendarRepo = calendarRepo
    }

    public var filteredEvents: [CalendarUnifiedEvent] {
        if selectedCategory == .all {
            return events.sorted { $0.date < $1.date }
        }
        return events
            .filter { $0.category == selectedCategory }
            .sorted { $0.date < $1.date }
    }

    public func loadCalendarEvents() async {
        isLoading = true
        do {
            async let examsTask = calendarRepo.getAllExams()
            async let assignmentsTask = calendarRepo.getAllAssignments()
            async let lecturesTask = calendarRepo.getAllLectures()
            async let studyTask = calendarRepo.getAllStudySessions()

            let (exams, assignments, lectures, sessions) = try await (examsTask, assignmentsTask, lecturesTask, studyTask)

            var unified: [CalendarUnifiedEvent] = []

            for exam in exams {
                unified.append(CalendarUnifiedEvent(
                    id: exam.id,
                    title: exam.title,
                    subtitle: "\(exam.room) • Weight \(exam.weightPercentage)%",
                    date: exam.examDate,
                    category: .exams,
                    color: Color.academicCrimson
                ))
            }

            for assignment in assignments {
                unified.append(CalendarUnifiedEvent(
                    id: assignment.id,
                    title: assignment.title,
                    subtitle: "Status: \(assignment.status.rawValue)",
                    date: assignment.dueDate,
                    category: .assignments,
                    color: Color.academicAmber
                ))
            }

            for lecture in lectures {
                unified.append(CalendarUnifiedEvent(
                    id: lecture.id,
                    title: lecture.title,
                    subtitle: "\(lecture.room) • \(lecture.durationMinutes) min",
                    date: lecture.sessionDate,
                    category: .classes,
                    color: Color.academicPrimary
                ))
            }

            for session in sessions {
                unified.append(CalendarUnifiedEvent(
                    id: session.id,
                    title: session.title,
                    subtitle: "\(session.targetDurationMinutes) min • Focus Rating: \(session.focusRating)/5",
                    date: session.scheduledDate,
                    category: .study,
                    color: Color.academicEmerald
                ))
            }

            // Always add a sample study session if none loaded
            if unified.filter({ $0.category == .study }).isEmpty {
                unified.append(CalendarUnifiedEvent(
                    title: "Research Methods Study Block",
                    subtitle: "SPSS Quantitative Survey Lab Review",
                    date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                    category: .study,
                    color: Color.academicEmerald
                ))
            }

            self.events = unified
        } catch {
            print("Calendar load error: \(error)")
        }
        isLoading = false
    }
}
