import XCTest
@testable import AcademicOSKit

/// Mock speech provider for validating on-device detection and capability states.
final class MockSpeechTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    var mockCapability: TranscriptionCapability
    var providerName: String = "Mock Speech Provider"
    var didUploadToCloud: Bool = false

    init(capability: TranscriptionCapability = .onDeviceAvailable) {
        self.mockCapability = capability
    }

    func checkCapability() -> TranscriptionCapability {
        return mockCapability
    }

    func transcribeChunk(
        audioURL: URL,
        recordingId: UUID,
        courseId: UUID,
        startTimeSeconds: Double,
        chunkDurationSeconds: Double,
        requireOnDevice: Bool
    ) async throws -> [TranscriptSegment] {
        if !requireOnDevice {
            didUploadToCloud = true
        }

        if requireOnDevice && !mockCapability.canTranscribeOffline {
            throw AcademicOSError.aiProviderUnavailable("On-device speech recognition is not supported on this device/locale.")
        }

        return [
            TranscriptSegment(
                recordingId: recordingId,
                courseId: courseId,
                startSeconds: startTimeSeconds,
                endSeconds: startTimeSeconds + chunkDurationSeconds,
                text: "Transcribed sample audio text.",
                confidence: 0.98
            )
        ]
    }
}

/// Validates Speech.framework capability checks, on-device detection, and privacy protection.
final class SpeechOnDeviceDetectionTests: XCTestCase {
    private var localStore: InMemoryDatabaseManager!
    private var recordingRepo: DatabaseRecordingRepository!
    private var sampleRecording: AudioRecordingMetadata!

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        recordingRepo = DatabaseRecordingRepository(localStore: localStore)

        // Create a dummy physical file so existence check passes
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let sampleURL = recordingsDir.appendingPathComponent("test_speech_rec.m4a")
        try? "dummy audio bytes".data(using: .utf8)?.write(to: sampleURL)

        sampleRecording = AudioRecordingMetadata(
            id: UUID(),
            courseId: UUID(),
            lectureSessionId: UUID(),
            localRelativePath: "Recordings/test_speech_rec.m4a",
            durationSeconds: 120.0,
            fileSizeByte: 1024,
            transcriptionStatus: .notStarted
        )
        try await recordingRepo.saveRecording(sampleRecording)
    }

    override func tearDown() async throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sampleURL = docs.appendingPathComponent("Recordings/test_speech_rec.m4a")
        try? FileManager.default.removeItem(at: sampleURL)
        try await super.tearDown()
    }

    @MainActor
    func testOnDeviceUnavailableEntersWaitingForCapabilityWithoutCloudUpload() async throws {
        // When recognizer reports supportsOnDeviceRecognition == false -> capability is cloudRecognitionAvailable
        let mockProvider = MockSpeechTranscriptionProvider(capability: .cloudRecognitionAvailable)
        let service = TranscriptionService(provider: mockProvider, recordingRepo: recordingRepo)

        // User requested offline-only transcription (requireOnDevice = true)
        do {
            _ = try await service.transcribeRecording(recording: sampleRecording, requireOnDevice: true)
            XCTFail("Should have thrown aiProviderUnavailable when on-device is not supported")
        } catch {
            // Assert that audio was NOT uploaded silently to cloud!
            XCTAssertFalse(mockProvider.didUploadToCloud, "Must never silently upload audio to cloud without permission")

            // Assert status is set to waitingForCapability
            let updated = try await recordingRepo.getRecording(id: sampleRecording.id)
            XCTAssertEqual(updated?.transcriptionStatus, .waitingForCapability)
            XCTAssertNotNil(updated?.lastError)
            XCTAssertTrue(updated?.lastError?.contains("On-device speech recognition is unavailable") ?? false)

            // Assert audio file is kept safe
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(sampleRecording.localRelativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Audio file must remain safely stored on disk")
        }
    }

    @MainActor
    func testPermissionDeniedSetsFailedAndPreservesAudio() async throws {
        let mockProvider = MockSpeechTranscriptionProvider(capability: .authorizationDenied)
        let service = TranscriptionService(provider: mockProvider, recordingRepo: recordingRepo)

        do {
            _ = try await service.transcribeRecording(recording: sampleRecording, requireOnDevice: true)
            XCTFail("Should have thrown unauthorized error")
        } catch {
            let updated = try await recordingRepo.getRecording(id: sampleRecording.id)
            XCTAssertEqual(updated?.transcriptionStatus, .failed)
            XCTAssertTrue(updated?.lastError?.contains("permission denied") ?? false)

            // Audio is preserved
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(sampleRecording.localRelativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    func testTranscriptionCapabilityProperties() {
        XCTAssertTrue(TranscriptionCapability.onDeviceAvailable.canTranscribeOffline)
        XCTAssertFalse(TranscriptionCapability.cloudRecognitionAvailable.canTranscribeOffline)
        XCTAssertFalse(TranscriptionCapability.authorizationDenied.canTranscribeOffline)
        XCTAssertFalse(TranscriptionCapability.recognizerUnavailable.canTranscribeOffline)
        XCTAssertFalse(TranscriptionCapability.localeUnsupported.canTranscribeOffline)
    }
}
