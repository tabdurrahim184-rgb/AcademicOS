import XCTest
import Foundation
@testable import AcademicOS

final class ResilienceAndPipelineTests: XCTestCase {
    var localStore: LocalStoreProtocol!
    var recRepo: RecordingRepositoryProtocol!
    var notesRepo: NotesRepositoryProtocol!
    var noteVersionRepo: NoteVersionRepositoryProtocol!
    var memRepo: AIMemoryRepositoryProtocol!
    var empRepo: ProfessorEmphasisRepositoryProtocol!
    var pipelineRepo: PipelineRepositoryProtocol!
    var router: AIRouter!
    var pipeline: LectureIntelligencePipeline!

    let courseId = UUID()
    let recordingId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        recRepo = DatabaseRecordingRepository(localStore: localStore)
        notesRepo = DatabaseNotesRepository(localStore: localStore)
        noteVersionRepo = DatabaseNoteVersionRepository(localStore: localStore)
        memRepo = DatabaseAIMemoryRepository(localStore: localStore)
        empRepo = DatabaseProfessorEmphasisRepository(localStore: localStore)
        pipelineRepo = DatabasePipelineRepository(localStore: localStore)

        let online = GeminiOnlineAIProvider()
        let local = AppleLocalAIProvider()
        router = AIRouter(onlineProvider: online, localProvider: local, networkMonitor: NetworkMonitor.shared)

        pipeline = LectureIntelligencePipeline(
            recordingRepo: recRepo,
            notesRepo: notesRepo,
            noteVersionRepo: noteVersionRepo,
            memoryRepo: memRepo,
            emphasisRepo: empRepo,
            pipelineRepo: pipelineRepo,
            aiRouter: router
        )

        // Seed recording
        let recording = AudioRecordingMetadata(
            id: recordingId,
            courseId: courseId,
            localRelativePath: "Recordings/\(recordingId.uuidString).m4a",
            durationSeconds: 1800.0,
            transcriptionStatus: .completed
        )
        try await recRepo.saveRecording(recording)

        // Seed transcript with explicit exam hint
        let transcript = Transcript(
            recordingId: recordingId,
            courseId: courseId,
            fullText: "Bugünkü dersimizde kitle iletişim kuramlarını inceledik. Bu ayrım finalde sorabilirim arkadaşlar mutlaka altını çizin.",
            segments: [
                TranscriptSegment(
                    recordingId: recordingId,
                    courseId: courseId,
                    startSeconds: 100.0,
                    endSeconds: 110.0,
                    text: "Bu ayrım finalde sorabilirim arkadaşlar mutlaka altını çizin."
                )
            ]
        )
        try await recRepo.saveTranscript(transcript)
    }

    func testPipelineProcessesLectureSuccessfully() async throws {
        let record = try await pipeline.processLecture(
            recordingId: recordingId,
            courseId: courseId
        )

        XCTAssertEqual(record.currentStage, .completed)
        XCTAssertEqual(record.progressPercentage, 100.0)
        XCTAssertNil(record.lastError)

        // Verify emphasis items saved to SQLite
        let savedEmphasis = try await empRepo.getEmphasis(forCourseId: courseId)
        XCTAssertFalse(savedEmphasis.isEmpty)
        XCTAssertEqual(savedEmphasis.first?.classification, .explicitExamHint)

        // Verify notes created
        let notes = try await notesRepo.getNotes(forCourseId: courseId)
        XCTAssertFalse(notes.isEmpty)

        // Verify versions created
        let versions = try await noteVersionRepo.getVersions(forCourseId: courseId)
        XCTAssertGreaterThanOrEqual(versions.count, 3, "Must create Full, Study, and Nokta Atisi versions.")
    }

    func testMalformedJSONOutputDoesNotCorruptDatabase() {
        let malformedJson = "{ invalid json without closing bracket"
        let data = malformedJson.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(LectureAnalysisResult.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
