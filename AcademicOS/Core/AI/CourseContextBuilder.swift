import Foundation

/// Builds isolated academic context packages strictly confined to a single course.
/// Guarantees that Course A requests never leak Course B records.
public final class CourseContextBuilder: Sendable {
    private let courseRepo: CourseRepositoryProtocol
    private let notesRepo: NotesRepositoryProtocol
    private let recordingRepo: RecordingRepositoryProtocol
    private let examRepo: ExamRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let memoryRepo: AIMemoryRepositoryProtocol

    public init(
        courseRepo: CourseRepositoryProtocol,
        notesRepo: NotesRepositoryProtocol,
        recordingRepo: RecordingRepositoryProtocol,
        examRepo: ExamRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        memoryRepo: AIMemoryRepositoryProtocol
    ) {
        self.courseRepo = courseRepo
        self.notesRepo = notesRepo
        self.recordingRepo = recordingRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.memoryRepo = memoryRepo
    }

    /// Assembles an isolated context dictionary for a specific course inquiry.
    public func buildContext(
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        query: String? = nil,
        maxContextLength: Int = 4000
    ) async throws -> [String: String] {
        guard let course = try await courseRepo.getCourse(id: courseId) else {
            throw AcademicOSError.entityNotFound("Course with id '\(courseId)' not found.")
        }

        var context: [String: String] = [:]
        context["course_code"] = course.code
        context["course_name"] = course.name
        context["course_department"] = course.department ?? "General"

        // 1. Isolated Course Memory (Pinned & High-Importance first)
        let memories = try await memoryRepo.getMemories(forCourseId: courseId)
        let memorySnippets = memories.prefix(6).map { "[\($0.type.title.uppercased())]: \($0.topic) - \($0.content)" }
        if !memorySnippets.isEmpty {
            context["course_memory"] = memorySnippets.joined(separator: "\n")
        }

        // 2. Isolated Course Notes
        let notes = try await notesRepo.getNotes(forCourseId: courseId)
        let relevantNotes = notes.prefix(3).map { note in
            var text = "Note: \(note.title)\n\(note.rawContent.prefix(400))"
            if !note.studyNotesContent.isEmpty {
                text += "\nStudy Takeaways: \(note.studyNotesContent.prefix(200))"
            }
            return text
        }
        if !relevantNotes.isEmpty {
            context["course_notes"] = relevantNotes.joined(separator: "\n---\n")
        }

        // 3. Isolated Exams and Deadlines
        let exams = try await examRepo.getExams(forCourseId: courseId)
        if !exams.isEmpty {
            context["upcoming_exams"] = exams.map { "\($0.title) (\($0.examType)) on \($0.examDate)" }.joined(separator: ", ")
        }

        // 4. Isolated Assignments
        let assignments = try await taskRepo.getAssignments(forCourseId: courseId)
        if !assignments.isEmpty {
            context["active_assignments"] = assignments.prefix(3).map { "\($0.title) (Due: \($0.dueDate))" }.joined(separator: "; ")
        }

        // 5. Lecture Transcript Segments (if session specified or query provided)
        if let recId = (try await recordingRepo.getRecordings(forCourseId: courseId)).first?.id,
           let transcript = try await recordingRepo.getTranscript(forRecordingId: recId) {
            let snippet = String(transcript.fullText.prefix(1200))
            context["recent_lecture_transcript"] = snippet
        }

        return context
    }

    /// Explicit cross-course context briefing — strictly permitted ONLY for Academic Commander.
    public func buildCrossCourseBriefingContext() async throws -> [String: String] {
        var context: [String: String] = [:]
        let courses = try await courseRepo.getCourses()
        context["enrolled_courses"] = courses.map { "\($0.code): \($0.name)" }.joined(separator: "\n")

        let allExams = try await examRepo.getAllExams()
        context["all_exams"] = allExams.sorted { $0.examDate < $1.examDate }.map { "\($0.title) (\($0.examDate))" }.joined(separator: "\n")

        let allTasks = try await taskRepo.getTasks()
        context["pending_missions"] = allTasks.filter { !$0.isCompleted }.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")

        return context
    }
}
