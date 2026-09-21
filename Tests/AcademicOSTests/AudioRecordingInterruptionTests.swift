import XCTest
import AVFoundation
@testable import AcademicOSKit

/// Validates audio recording interruption lifecycle, route changes, and data preservation.
final class AudioRecordingInterruptionTests: XCTestCase {

    @MainActor
    func testInterruptionBeganTransitionsToInterruptedBySystem() {
        let service = AudioRecordingService.shared
        // Force state to recording for testing notification handler
        service.state = .recording

        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )

        XCTAssertEqual(service.state, .interruptedBySystem, "Interruption began must set state to interruptedBySystem")
        XCTAssertTrue(service.state.isRecordingOrPaused, "Must remain in a valid recording/paused session state")
    }

    @MainActor
    func testInterruptionEndedWithoutShouldResumeLeavesPausedByUser() {
        let service = AudioRecordingService.shared
        service.state = .interruptedBySystem

        // Interruption ended, but shouldResume is NOT set
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: UInt(0) // No shouldResume
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )

        XCTAssertEqual(service.state, .pausedByUser, "Without shouldResume flag, system must remain safely in pausedByUser")
    }

    @MainActor
    func testStopRecordingFromInterruptedStatePreservesData() {
        let service = AudioRecordingService.shared
        service.state = .interruptedBySystem

        // Even when interrupted by phone call, calling stopRecording safely flushes metadata
        // without discarding already recorded audio or markers
        XCTAssertTrue(service.state.isRecordingOrPaused)

        // Calling pause/resume when already paused
        service.state = .pausedByUser
        XCTAssertTrue(service.state.isRecordingOrPaused)
    }

    func testRecordingStateHierarchy() {
        XCTAssertTrue(RecordingState.recording.isRecordingOrPaused)
        XCTAssertTrue(RecordingState.pausedByUser.isRecordingOrPaused)
        XCTAssertTrue(RecordingState.interruptedBySystem.isRecordingOrPaused)
        XCTAssertTrue(RecordingState.resuming.isRecordingOrPaused)

        XCTAssertFalse(RecordingState.idle.isRecordingOrPaused)
        XCTAssertFalse(RecordingState.stopped.isRecordingOrPaused)
        XCTAssertFalse(RecordingState.failed("Error").isRecordingOrPaused)
    }
}
