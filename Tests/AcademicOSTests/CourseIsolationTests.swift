import XCTest
@testable import AcademicOSKit

/// Validates strict course isolation invariant:
/// Queries for Course A must strictly never return sub-entities (notes, transcripts, recordings, markers, exams, flashcards) belonging to Course B.
final class CourseIsolationTests: XCTestCase {
    private var localStore: InMemoryDatabaseManager!
    private var courseRepo: DatabaseCourseRepository!
    private var notesRepo: DatabaseNotesRepository!
    private var lectureRepo: DatabaseLectureRepository!
    private var recordingRepo: DatabaseRecordingRepository!
    private var examRepo: DatabaseExamRepository!
    private var flashcardRepo: DatabaseFlashcardRepository!

    private let courseAId = UUID()
    private let courseBId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        courseRepo = DatabaseCourseRepository(localStore: localStore)
        notesRepo = DatabaseNotesRepository(localStore: localStore)
        lectureRepo = DatabaseLectureRepository(localStore: localStore)
        recordingRepo = DatabaseRecordingRepository(localStore: localStore)
        examRepo = DatabaseExamRepository(localStore: localStore)
        flashcardRepo = DatabaseFlashcardRepository(localStore: localStore)

        // Seed two separate courses
        let courseA = Course(
            id: courseAId,
            code: "COMM 401",
            name: "Communication Law",
            department: "Journalism",
            credits: 4,
            semesterId: UUID()
        )
        let courseB = Course(
            id: courseBId,
            code: "COMM 403",
            name: "Communication Theories",
            department: "Journalism",
            credits: 4,
            semesterId: UUID()
        )
        try await courseRepo.saveCourse(courseA)
        try await courseRepo.saveCourse(courseB)
    }

    func testNotesCourseIsolation() async throws {
        let noteA = Note(
            courseId: courseAId,
            title: "Law Precedents Article 125",
            rawContent: "Content for Law"
        )
        let noteB = Note(
            courseId: courseBId,
            title: "Frankfurt School and Cultural Hegemony",
            rawContent: "Content for Theories"
        )

        try await notesRepo.saveNote(noteA)
        try await notesRepo.saveNote(noteB)

        let notesA = try await notesRepo.getNotes(forCourseId: courseAId)
        let notesB = try await notesRepo.getNotes(forCourseId: courseBId)

        XCTAssertEqual(notesA.count, 1)
        XCTAssertEqual(notesA.first?.id, noteA.id)
        XCTAssertEqual(notesA.first?.title, "Law Precedents Article 125")

        XCTAssertEqual(notesB.count, 1)
        XCTAssertEqual(notesB.first?.id, noteB.id)
        XCTAssertEqual(notesB.first?.title, "Frankfurt School and Cultural Hegemony")

        // Cross-contamination verification
        XCTAssertFalse(notesA.contains(where: { $0.courseId == courseBId }))
        XCTAssertFalse(notesB.contains(where: { $0.courseId == courseAId }))
    }

    func testLectureSessionCourseIsolation() async throws {
        let lectureA = LectureSession(
            courseId: courseAId,
            title: "Law Week 1: Turkish Press Code",
            sessionDate: Date()
        )
        let lectureB = LectureSession(
            courseId: courseBId,
            title: "Theories Week 1: Public Sphere",
            sessionDate: Date()
        )

        try await lectureRepo.saveLecture(lectureA)
        try await lectureRepo.saveLecture(lectureB)

        let lecturesA = try await lectureRepo.getLectures(forCourseId: courseAId)
        let lecturesB = try await lectureRepo.getLectures(forCourseId: courseBId)

        XCTAssertEqual(lecturesA.count, 1)
        XCTAssertEqual(lecturesA.first?.id, lectureA.id)
        XCTAssertFalse(lecturesA.contains(where: { $0.courseId == courseBId }))

        XCTAssertEqual(lecturesB.count, 1)
        XCTAssertEqual(lecturesB.first?.id, lectureB.id)
        XCTAssertFalse(lecturesB.contains(where: { $0.courseId == courseAId }))
    }

    func testRecordingsAndMarkersCourseIsolation() async throws {
        let recA = AudioRecordingMetadata(
            courseId: courseAId,
            lectureSessionId: UUID(),
            filename: "law_rec_1.m4a",
            durationSeconds: 3600.0,
            fileSizeBytes: 28800000
        )
        let recB = AudioRecordingMetadata(
            courseId: courseBId,
            lectureSessionId: UUID(),
            filename: "theories_rec_1.m4a",
            durationSeconds: 1800.0,
            fileSizeBytes: 14400000
        )

        try await recordingRepo.saveRecording(recA)
        try await recordingRepo.saveRecording(recB)

        let recsA = try await recordingRepo.getRecordings(forCourseId: courseAId)
        let recsB = try await recordingRepo.getRecordings(forCourseId: courseBId)

        XCTAssertEqual(recsA.count, 1)
        XCTAssertEqual(recsA.first?.id, recA.id)
        XCTAssertFalse(recsA.contains(where: { $0.courseId == courseBId }))

        // Moment Markers
        let markerA = AudioMarker(
            recordingId: recA.id,
            courseId: courseAId,
            timestampSeconds: 120.0,
            label: "Exam Hint: Supreme Court Ruling",
            category: .examHint
        )
        let markerB = AudioMarker(
            recordingId: recB.id,
            courseId: courseBId,
            timestampSeconds: 300.0,
            label: "Definition: Agenda Setting",
            category: .definition
        )

        try await recordingRepo.saveMarker(markerA)
        try await recordingRepo.saveMarker(markerB)

        let markersA = try await recordingRepo.getMarkers(forCourseId: courseAId)
        let markersB = try await recordingRepo.getMarkers(forCourseId: courseBId)

        XCTAssertEqual(markersA.count, 1)
        XCTAssertEqual(markersA.first?.id, markerA.id)
        XCTAssertFalse(markersA.contains(where: { $0.courseId == courseBId }))

        XCTAssertEqual(markersB.count, 1)
        XCTAssertEqual(markersB.first?.id, markerB.id)
        XCTAssertFalse(markersB.contains(where: { $0.courseId == courseAId }))
    }

    func testExamsCourseIsolation() async throws {
        let examA = Exam(
            courseId: courseAId,
            title: "Law Midterm Exam",
            examType: .midterm,
            examDate: Date().addingTimeInterval(86400 * 7),
            room: "Amphi 1",
            weightPercentage: 40
        )
        let examB = Exam(
            courseId: courseBId,
            title: "Theories Final Exam",
            examType: .finalExam,
            examDate: Date().addingTimeInterval(86400 * 14),
            room: "Amphi 3",
            weightPercentage: 50
        )

        try await examRepo.saveExam(examA)
        try await examRepo.saveExam(examB)

        let examsA = try await examRepo.getExams(forCourseId: courseAId)
        let examsB = try await examRepo.getExams(forCourseId: courseBId)

        XCTAssertEqual(examsA.count, 1)
        XCTAssertEqual(examsA.first?.id, examA.id)
        XCTAssertFalse(examsA.contains(where: { $0.courseId == courseBId }))

        XCTAssertEqual(examsB.count, 1)
        XCTAssertEqual(examsB.first?.id, examB.id)
        XCTAssertFalse(examsB.contains(where: { $0.courseId == courseAId }))
    }

    func testFlashcardsCourseIsolation() async throws {
        let cardA = Flashcard(
            courseId: courseAId,
            deckTitle: "TCK Law",
            question: "Article 125 element?",
            answer: "Defamation"
        )
        let cardB = Flashcard(
            courseId: courseBId,
            deckTitle: "Theories",
            question: "Agenda Setting author?",
            answer: "McCombs & Shaw"
        )

        try await flashcardRepo.saveFlashcard(cardA)
        try await flashcardRepo.saveFlashcard(cardB)

        let cardsA = try await flashcardRepo.getFlashcards(forCourseId: courseAId)
        let cardsB = try await flashcardRepo.getFlashcards(forCourseId: courseBId)

        XCTAssertEqual(cardsA.count, 1)
        XCTAssertEqual(cardsA.first?.id, cardA.id)
        XCTAssertFalse(cardsA.contains(where: { $0.courseId == courseBId }))

        XCTAssertEqual(cardsB.count, 1)
        XCTAssertEqual(cardsB.first?.id, cardB.id)
        XCTAssertFalse(cardsB.contains(where: { $0.courseId == courseAId }))
    }
}
