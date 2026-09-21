import Foundation

/// Repository contract for student profile and onboarding information.
public protocol StudentRepositoryProtocol: Sendable {
    func getStudent() async throws -> StudentProfile?
    func saveStudent(_ student: StudentProfile) async throws
    func deleteStudent() async throws
}

/// Repository contract for academic semesters.
public protocol SemesterRepositoryProtocol: Sendable {
    func getSemesters() async throws -> [Semester]
    func getActiveSemester() async throws -> Semester?
    func saveSemester(_ semester: Semester) async throws
    func setActiveSemester(id: UUID) async throws
    func deleteSemester(id: UUID) async throws
}

/// Repository contract for courses (with strict course isolation).
public protocol CourseRepositoryProtocol: Sendable {
    func getCourses() async throws -> [Course]
    func getCourse(id: UUID) async throws -> Course?
    func getCourses(forSemesterId semesterId: UUID) async throws -> [Course]
    func saveCourse(_ course: Course) async throws
    func archiveCourse(id: UUID) async throws
    func deleteCourse(id: UUID) async throws
}

/// Repository contract for scheduled lecture sessions.
public protocol LectureRepositoryProtocol: Sendable {
    func getLectures(forCourseId courseId: UUID) async throws -> [LectureSession]
    func getLecture(id: UUID) async throws -> LectureSession?
    func getAllLectures() async throws -> [LectureSession]
    func saveLecture(_ lecture: LectureSession) async throws
    func deleteLecture(id: UUID) async throws
}

/// Repository contract for lecture notes and study summaries.
public protocol NotesRepositoryProtocol: Sendable {
    func getNotes(forCourseId courseId: UUID) async throws -> [Note]
    func getNote(id: UUID) async throws -> Note?
    func searchNotes(query: String, courseId: UUID?) async throws -> [Note]
    func saveNote(_ note: Note) async throws
    func togglePin(id: UUID) async throws
    func deleteNote(id: UUID) async throws
}

/// Repository contract for audio recordings, transcripts, and moment markers.
public protocol RecordingRepositoryProtocol: Sendable {
    func getRecordings(forCourseId courseId: UUID) async throws -> [AudioRecordingMetadata]
    func getRecording(id: UUID) async throws -> AudioRecordingMetadata?
    func saveRecording(_ recording: AudioRecordingMetadata) async throws
    func deleteRecording(id: UUID) async throws

    // Transcripts
    func getTranscript(forRecordingId recordingId: UUID) async throws -> Transcript?
    func saveTranscript(_ transcript: Transcript) async throws
    func saveTranscriptSegment(_ segment: TranscriptSegment) async throws
    func getSegments(forTranscriptId transcriptId: UUID) async throws -> [TranscriptSegment]

    // Moment Markers
    func getMarkers(forRecordingId recordingId: UUID) async throws -> [AudioMarker]
    func getMarkers(forCourseId courseId: UUID) async throws -> [AudioMarker]
    func saveMarker(_ marker: AudioMarker) async throws
    func deleteMarker(id: UUID) async throws
}

/// Repository contract for examinations.
public protocol ExamRepositoryProtocol: Sendable {
    func getExams(forCourseId courseId: UUID) async throws -> [Exam]
    func getAllExams() async throws -> [Exam]
    func getExam(id: UUID) async throws -> Exam?
    func saveExam(_ exam: Exam) async throws
    func deleteExam(id: UUID) async throws
}

/// Repository contract for assignments and tasks.
public protocol TaskRepositoryProtocol: Sendable {
    func getTasks() async throws -> [AcademicTask]
    func getTodaysMissions() async throws -> [AcademicTask]
    func saveTask(_ task: AcademicTask) async throws
    func toggleTaskCompletion(id: UUID) async throws
    func deleteTask(id: UUID) async throws

    // Assignments
    func getAssignments(forCourseId courseId: UUID) async throws -> [Assignment]
    func getAllAssignments() async throws -> [Assignment]
    func saveAssignment(_ assignment: Assignment) async throws
    func deleteAssignment(id: UUID) async throws
}

/// Repository contract for spaced repetition flashcards.
public protocol FlashcardRepositoryProtocol: Sendable {
    func getFlashcards(forCourseId courseId: UUID) async throws -> [Flashcard]
    func getAllDueFlashcards() async throws -> [Flashcard]
    func saveFlashcard(_ card: Flashcard) async throws
    func updateReview(id: UUID, difficulty: Int) async throws
    func deleteFlashcard(id: UUID) async throws
}

/// Repository contract for graduation calculations.
public protocol GraduationRepositoryProtocol: Sendable {
    func getGraduationProgress() async throws -> GraduationProgress
    func updateGraduationProgress(_ progress: GraduationProgress) async throws
}

/// Repository contract for unified offline local search across all entities.
public protocol SearchRepositoryProtocol: Sendable {
    func searchAll(query: String) async throws -> UnifiedSearchResults
}

/// Container for unified multi-entity search results.
public struct UnifiedSearchResults: Sendable {
    public let query: String
    public let courses: [Course]
    public let notes: [Note]
    public let transcripts: [Transcript]
    public let exams: [Exam]
    public let assignments: [Assignment]

    public var isEmpty: Bool {
        courses.isEmpty && notes.isEmpty && transcripts.isEmpty && exams.isEmpty && assignments.isEmpty
    }
}

/// Repository contract for course-specific AI memory items.
public protocol AIMemoryRepositoryProtocol: Sendable {
    func getMemories(forCourseId courseId: UUID) async throws -> [AIMemoryEntry]
    func getMemories(forCourseId courseId: UUID, type: AIMemoryType) async throws -> [AIMemoryEntry]
    func saveMemory(_ entry: AIMemoryEntry) async throws
    func deleteMemory(id: UUID) async throws
    func togglePin(id: UUID) async throws
    func searchMemories(query: String, courseId: UUID) async throws -> [AIMemoryEntry]
}

/// Repository contract for immutable / user-edited AI note versions.
public protocol NoteVersionRepositoryProtocol: Sendable {
    func getVersions(forNoteId noteId: UUID) async throws -> [AINoteVersion]
    func getVersions(forCourseId courseId: UUID) async throws -> [AINoteVersion]
    func getLatestVersion(forNoteId noteId: UUID, mode: NoteMode) async throws -> AINoteVersion?
    func saveVersion(_ version: AINoteVersion) async throws
    func deleteVersion(id: UUID) async throws
}

/// Repository contract for topic-level student academic mastery tracking.
public protocol MasteryRepositoryProtocol: Sendable {
    func getMastery(forCourseId courseId: UUID) async throws -> [AcademicMastery]
    func getMastery(forCourseId courseId: UUID, topic: String) async throws -> AcademicMastery?
    func saveMastery(_ record: AcademicMastery) async throws
    func deleteMastery(id: UUID) async throws
}

/// Repository contract for detected professor emphasis and exam hints.
public protocol ProfessorEmphasisRepositoryProtocol: Sendable {
    func getEmphasis(forCourseId courseId: UUID) async throws -> [ProfessorEmphasis]
    func getEmphasis(forRecordingId recordingId: UUID) async throws -> [ProfessorEmphasis]
    func saveEmphasis(_ item: ProfessorEmphasis) async throws
    func saveAllEmphasis(_ items: [ProfessorEmphasis]) async throws
    func deleteEmphasis(id: UUID) async throws
}

/// Repository contract for tracking resumable Lecture Intelligence Pipeline jobs.
public protocol PipelineRepositoryProtocol: Sendable {
    func getPipeline(forRecordingId recordingId: UUID) async throws -> LecturePipelineRecord?
    func getPipelines(forCourseId courseId: UUID) async throws -> [LecturePipelineRecord]
    func savePipeline(_ record: LecturePipelineRecord) async throws
    func deletePipeline(id: UUID) async throws
}
