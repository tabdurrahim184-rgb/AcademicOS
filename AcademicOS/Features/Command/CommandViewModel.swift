import SwiftUI
import Combine

/// State management and business logic for the Command Dashboard.
/// Powered by real local SQLite data without mock overrides.
@MainActor
public final class CommandViewModel: ObservableObject {
    @Published public var studentProfile: StudentProfile?
    @Published public var graduationProgress: GraduationProgress?
    @Published public var coursesCount: Int = 0
    @Published public var examsCount: Int = 0
    @Published public var assignmentsCount: Int = 0
    @Published public var tasksCount: Int = 0
    @Published public var todaysMissions: [AcademicTask] = []
    @Published public var upcomingExams: [Exam] = []
    @Published public var upcomingAssignments: [Assignment] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let studentRepo: StudentRepositoryProtocol
    private let courseRepo: CourseRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let examRepo: ExamRepositoryProtocol
    private let gradRepo: GraduationRepositoryProtocol

    public init(
        studentRepo: StudentRepositoryProtocol,
        courseRepo: CourseRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        examRepo: ExamRepositoryProtocol,
        gradRepo: GraduationRepositoryProtocol
    ) {
        self.studentRepo = studentRepo
        self.courseRepo = courseRepo
        self.taskRepo = taskRepo
        self.examRepo = examRepo
        self.gradRepo = gradRepo
    }

    public func loadDashboardData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let studentTask = studentRepo.getStudent()
            async let gradTask = gradRepo.getGraduationProgress()
            async let coursesTask = courseRepo.getCourses()
            async let examsTask = examRepo.getAllExams()
            async let assignmentsTask = taskRepo.getAllAssignments()
            async let missionsTask = taskRepo.getTodaysMissions()
            async let tasksTask = taskRepo.getTasks()

            let (student, grad, courses, exams, assignments, missions, allTasks) = try await (
                studentTask, gradTask, coursesTask, examsTask, assignmentsTask, missionsTask, tasksTask
            )

            self.studentProfile = student
            self.graduationProgress = grad
            self.coursesCount = courses.count
            self.examsCount = exams.count
            self.assignmentsCount = assignments.count
            self.todaysMissions = missions
            self.upcomingExams = Array(exams.prefix(3))
            self.upcomingAssignments = Array(assignments.prefix(3))
            self.tasksCount = allTasks.filter { $0.category != .mission && !$0.isCompleted }.count
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func toggleMissionCompletion(id: UUID) async {
        do {
            try await taskRepo.toggleTaskCompletion(id: id)
            if let index = todaysMissions.firstIndex(where: { $0.id == id }) {
                todaysMissions[index].isCompleted.toggle()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
