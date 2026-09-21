import XCTest
@testable import AcademicOSKit

/// Mock chunked provider capable of simulating failure at a specific percentage.
final class FailingAt75PercentSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    var providerName: String = "Failing Chunk Provider"
    var shouldFailAt75: Bool = true
    var chunksProcessedCount: Int = 0

    func checkCapability() -> TranscriptionCapability {
        return .onDeviceAvailable
    }

    func transcribeChunk(
        audioURL: URL,
        recordingId: UUID,
        courseId: UUID,
        startTimeSeconds: Double,
        chunkDurationSeconds: Double,
        requireOnDevice: Bool
    ) async throws -> [TranscriptSegment] {
        chunksProcessedCount += 1

        // Chunks are 180s each. Total is 720s (4 chunks).
        // Chunk 1: 0..180 (25%)
        // Chunk 2: 180..360 (50%)
        // Chunk 3: 360..540 (75%)
        // Chunk 4: 540..720 (100%) - fails if shouldFailAt75 is true!
        if shouldFailAt75 && startTimeSeconds >= 540.0 {
            throw AcademicOSError.aiProviderUnavailable("Network / recognizer timeout on chunk 4 (75% mark)")
        }

        return [
            TranscriptSegment(
                recordingId: recordingId,
                courseId: courseId,
                startSeconds: startTimeSeconds,
                endSeconds: startTimeSeconds + chunkDurationSeconds,
                text: "Chunk \(chunksProcessedCount) transcribed speech [\(Int(startTimeSeconds))s - \(Int(startTimeSeconds + chunkDurationSeconds))s]",
                confidence: 0.95
            )
        ]
    }
}

/// Validates that partial transcription failure preserves all prior segments and allows clean resumption.
final class LongLectureTranscriptionSafetyTests: XCTestCase {
    private var localStore: InMemoryDatabaseManager!
    private var recordingRepo: DatabaseRecordingRepository!
    private var longRecording: AudioRecordingMetadata!

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        recordingRepo = DatabaseRecordingRepository(localStore: localStore)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let sampleURL = recordingsDir.appendingPathComponent("long_lecture_720s.m4a")
        try? "dummy long audio content".data(using: .utf8)?.write(to: sampleURL)

        longRecording = AudioRecordingMetadata(
            id: UUID(),
            courseId: UUID(),
            lectureSessionId: UUID(),
            localRelativePath: "Recordings/long_lecture_720s.m4a",
            durationSeconds: 720.0, // 12 minutes (4 chunks of 180s)
            fileSizeByte: 5760000,
            transcriptionStatus: .notStarted
        )
        try await recordingRepo.saveRecording(longRecording)
    }

    override func tearDown() async throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sampleURL = docs.appendingPathComponent("Recordings/long_lecture_720s.m4a")
        try? FileManager.default.removeItem(at: sampleURL)
        try await super.tearDown()
    }

    @MainActor
    func testFailureAt75PercentPreservesFirst75PercentOfSegments() async throws {
        let failingProvider = FailingAt75PercentSpeechProvider()
        let service = TranscriptionService(provider: failingProvider, recordingRepo: recordingRepo)

        do {
            _ = try await service.transcribeRecording(recording: longRecording, requireOnDevice: true)
            XCTFail("Should have thrown error on chunk 4")
        } catch {
            // 1. Verify metadata in SQLite was updated to reflect failure at 75%
            let updated = try await recordingRepo.getRecording(id: longRecording.id)
            XCTAssertNotNil(updated)
            XCTAssertEqual(updated?.transcriptionStatus, .failed)
            XCTAssertEqual(updated?.lastProcessedAudioTime, 540.0, "Must record progress up to chunk 3 (540s / 75%)")
            XCTAssertEqual(updated?.transcriptionProgress, 75.0, "Progress must be recorded as 75%")
            XCTAssertEqual(updated?.retryCount, 1)
            XCTAssertNotNil(updated?.lastError)

            // 2. Verify all segments up to 75% are PRESERVED in SQLite!
            let allSegments: [TranscriptSegment] = try await localStore.fetchAll()
            let recordingSegments = allSegments.filter { $0.recordingId == longRecording.id }
            XCTAssertEqual(recordingSegments.count, 3, "Chunks 1, 2, and 3 segments must survive in SQLite")

            // 3. Verify audio file was never deleted or corrupted
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(longRecording.localRelativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Audio file must remain safely stored on disk")
        }
    }
}
