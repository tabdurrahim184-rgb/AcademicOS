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
    private let notesRepo: NotesRepositoryProtocol
    private let lectureRepo: LectureRepositoryProtocol
    private let examRepo: ExamRepositoryProtocol
    private let flashcardRepo: FlashcardRepositoryProtocol
    private let localStore: LocalStoreProtocol

    public init(
        course: Course,
        notesRepo: NotesRepositoryProtocol? = nil,
        lectureRepo: LectureRepositoryProtocol? = nil,
        examRepo: ExamRepositoryProtocol? = nil,
        flashcardRepo: FlashcardRepositoryProtocol? = nil,
        localStore: LocalStoreProtocol? = nil
    ) {
        self.course = course
        self.notesRepo = notesRepo ?? AppContainer.shared.notesRepository
        self.lectureRepo = lectureRepo ?? AppContainer.shared.lectureRepository
        self.examRepo = examRepo ?? AppContainer.shared.examRepository
        self.flashcardRepo = flashcardRepo ?? AppContainer.shared.flashcardRepository
        self.localStore = localStore ?? AppContainer.shared.localStore
    }

    public func loadCourseData() async {
        isLoading = true
        do {
            async let notesTask = notesRepo.getNotes(forCourseId: course.id)
            async let lecturesTask = lectureRepo.getLectures(forCourseId: course.id)
            async let examsTask = examRepo.getExams(forCourseId: course.id)
            async let flashcardsTask = flashcardRepo.getFlashcards(forCourseId: course.id)
            async let docsTask: [AcademicDocument] = {
                let all: [AcademicDocument] = (try? await localStore.fetchAll()) ?? []
                return all.filter { $0.courseId == course.id }
            }()

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
