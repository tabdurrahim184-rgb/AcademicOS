import XCTest
@testable import AcademicOSKit

/// Validates audio recording configuration, file structure, state transitions, and moment tagging.
final class AudioRecordingResilienceTests: XCTestCase {

    func testAudioRecordingMetadataCreation() {
        let courseId = UUID()
        let lectureId = UUID()
        let filename = "lecture_COMM401_01.m4a"

        let metadata = AudioRecordingMetadata(
            courseId: courseId,
            lectureSessionId: lectureId,
            localRelativePath: "Recordings/\(filename)",
            durationSeconds: 5400.0, // 90 minutes
            fileSizeByte: 43_200_000, // ~43.2 MB (64kbps AAC mono)
            sampleRate: 44100.0,
            audioFormat: "m4a",
            transcriptionStatus: .notStarted
        )

        XCTAssertEqual(metadata.courseId, courseId)
        XCTAssertEqual(metadata.lectureSessionId, lectureId)
        XCTAssertEqual(metadata.localRelativePath, "Recordings/lecture_COMM401_01.m4a")
        XCTAssertEqual(metadata.durationSeconds, 5400.0)
        XCTAssertEqual(metadata.audioFormat, "m4a")
        XCTAssertEqual(metadata.sampleRate, 44100.0)
        XCTAssertEqual(metadata.transcriptionStatus, .notStarted)
    }

    func testAudioMarkerCreationAndTypes() {
        let recordingId = UUID()
        let courseId = UUID()

        let examMarker = AudioMarker(
            recordingId: recordingId,
            courseId: courseId,
            timestampSeconds: 154.5,
            markerType: .examHint,
            noteText: "Professor stressed: Midterm question on Press Code Article 125"
        )

        XCTAssertEqual(examMarker.recordingId, recordingId)
        XCTAssertEqual(examMarker.courseId, courseId)
        XCTAssertEqual(examMarker.timestampSeconds, 154.5)
        XCTAssertEqual(examMarker.markerType, .examHint)
        XCTAssertEqual(examMarker.noteText, "Professor stressed: Midterm question on Press Code Article 125")

        // Test all marker types
        let allTypes: [AudioMarkerType] = [.examHint, .important, .definition, .question, .assignment, .reviewLater]
        for type in allTypes {
            let m = AudioMarker(recordingId: recordingId, courseId: courseId, timestampSeconds: 10.0, markerType: type)
            XCTAssertEqual(m.markerType, type)
        }
    }

    func testRecordingStateTransitions() {
        var state: RecordingState = .idle
        XCTAssertEqual(state, .idle)
        XCTAssertFalse(state.isRecordingOrPaused)

        state = .recording
        XCTAssertEqual(state, .recording)
        XCTAssertTrue(state.isRecordingOrPaused)

        state = .pausedByUser
        XCTAssertEqual(state, .pausedByUser)
        XCTAssertTrue(state.isRecordingOrPaused)

        state = .interruptedBySystem
        XCTAssertEqual(state, .interruptedBySystem)
        XCTAssertTrue(state.isRecordingOrPaused)

        state = .resuming
        XCTAssertEqual(state, .resuming)
        XCTAssertTrue(state.isRecordingOrPaused)

        state = .stopped
        XCTAssertEqual(state, .stopped)
        XCTAssertFalse(state.isRecordingOrPaused)

        state = .failed("Permission denied")
        XCTAssertEqual(state, .failed("Permission denied"))
        XCTAssertFalse(state.isRecordingOrPaused)
    }

    func testAudioStorageFootprintCalculation() {
        // Voice speech mono 64 kbps AAC calculation:
        // 64,000 bits per second = 8,000 bytes per second
        // 1 hour (3600s) = 28,800,000 bytes (~27.5 MB)
        // 3 hours (10800s) = 86,400,000 bytes (~82.4 MB)
        let oneHourSeconds: Double = 3600.0
        let bytesPerSecond: Int64 = 8000
        let calculatedBytes = Int64(oneHourSeconds) * bytesPerSecond

        XCTAssertEqual(calculatedBytes, 28_800_000)
        let mbSize = Double(calculatedBytes) / (1024.0 * 1024.0)
        XCTAssert(mbSize > 27.0 && mbSize < 28.0)
    }
}
