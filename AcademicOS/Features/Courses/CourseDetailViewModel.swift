import SwiftUI
import Combine

/// State and data coordinator for Course Detail navigation and tabs.
@MainActor
public final class CourseDetailViewModel: ObservableObject {
    public enum CourseTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case notes = "Notes"
        case lectures = "Lectures"
        case recordings = "Recordings"
        case documents = "Documents"
        case exams = "Exams"
        case flashcards = "Flashcards"
        case ai = "AI"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .overview: return "info.circle"
            case .notes: return "note.text"
            case .lectures: return "person.wave.2"
            case .recordings: return "waveform"
            case .documents: return "doc"
            case .exams: return "doc.badge.gearshape"
            case .flashcards: return "rectangle.stack"
            case .ai: return "sparkles"
            }
        }
    }

    @Published public var selectedTab: CourseTab = .overview
    @Published public var notes: [Note] = []
    @Published public var lectures: [LectureSession] = []
    @Published public var exams: [Exam] = []
    @Published public var flashcards: [Flashcard] = []
    @Published public var documents: [AcademicDocument] = []
    @Published public var isLoading: Bool = false

    public let course: Course
    private let courseRepo: CourseRepositoryProtocol

    public init(course: Course, courseRepo: CourseRepositoryProtocol) {
        self.course = course
        self.courseRepo = courseRepo
    }

    public func loadCourseData() async {
        isLoading = true
        do {
            async let notesTask = courseRepo.getNotes(forCourseId: course.id)
            async let lecturesTask = courseRepo.getLectures(forCourseId: course.id)
            async let examsTask = courseRepo.getExams(forCourseId: course.id)
            async let flashcardsTask = courseRepo.getFlashcards(forCourseId: course.id)
            async let docsTask = courseRepo.getDocuments(forCourseId: course.id)

            let (n, l, e, f, d) = try await (notesTask, lecturesTask, examsTask, flashcardsTask, docsTask)

            self.notes = n
            self.lectures = l
            self.exams = e
            self.flashcards = f
            self.documents = d
        } catch {
            print("Course detail loading error: \(error)")
        }
        isLoading = false
    }
}
