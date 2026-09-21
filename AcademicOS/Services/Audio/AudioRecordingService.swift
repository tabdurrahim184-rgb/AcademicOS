import Foundation
import AVFoundation
import UIKit
import Combine

/// Operational states of the lecture recording engine with explicit interruption handling.
public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case pausedByUser
    case interruptedBySystem
    case resuming
    case stopped
    case failed(String)

    public var isRecordingOrPaused: Bool {
        switch self {
        case .recording, .pausedByUser, .interruptedBySystem, .resuming:
            return true
        case .idle, .stopped, .failed:
            return false
        }
    }
}

/// Production-grade audio recording service writing directly and progressively to disk.
/// Configured for long (60–180 min) lectures with zero memory exhaustion, lock-screen background recording,
/// interruption resilience (calls, Siri, routes), live audio metering, and moment tagging.
@MainActor
public final class AudioRecordingService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = AudioRecordingService()

    @Published public var state: RecordingState = .idle
    @Published public var elapsedSeconds: Double = 0.0
    @Published public var audioPowerLevel: Float = 0.0 // 0.0 to 1.0 normalized
    @Published public var currentMarkers: [AudioMarker] = []
    @Published public var hasMicrophonePermission: Bool = false

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentRecordingUrl: URL?
    private var currentCourseId: UUID?
    private var currentSessionId: UUID?
    private var currentRecordingId: UUID = UUID()

    private let fileManager = FileManager.default

    public override init() {
        super.init()
        checkMicrophonePermission()
        setupAudioSessionObservers()
    }

    // MARK: - Permission Flow
    public func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                self.hasMicrophonePermission = true
            case .denied, .undetermined:
                self.hasMicrophonePermission = false
            @unknown default:
                self.hasMicrophonePermission = false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                self.hasMicrophonePermission = true
            case .denied, .undetermined:
                self.hasMicrophonePermission = false
            @unknown default:
                self.hasMicrophonePermission = false
            }
        }
    }

    public func requestMicrophonePermission() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
        self.hasMicrophonePermission = granted
        return granted
    }

    // MARK: - Audio Session & Background Setup
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Call arrived or Siri activated: pause recording safely without losing data
            if state == .recording {
                audioRecorder?.pause()
                state = .interruptedBySystem
                timer?.invalidate()
            }
        case .ended:
            // Interruption concluded. Only resume if system authorizes and recorder is ready
            guard state == .interruptedBySystem else { return }

            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                state = .pausedByUser
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                state = .resuming
                do {
                    try configureAudioSession()
                    guard let recorder = audioRecorder, recorder.prepareToRecord(), recorder.record() else {
                        state = .pausedByUser
                        return
                    }
                    state = .recording
                    startMeteringTimer()
                } catch {
                    state = .pausedByUser
                }
            } else {
                // System does not allow automatic resume; leave in pausedByUser for manual resumption
                state = .pausedByUser
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // If headphones unplugged, check if recorder is still recording; if interrupted, pause safely
            if state == .recording {
                if let recorder = audioRecorder, !recorder.isRecording {
                    state = .pausedByUser
                    timer?.invalidate()
                }
            }
        default:
            break
        }
    }

    // MARK: - Recording Operations
    public func startRecording(
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        keepScreenAwake: Bool = true
    ) throws {
        guard hasMicrophonePermission else {
            throw AcademicOSError.unauthorized
        }

        try configureAudioSession()

        self.currentCourseId = courseId
        self.currentSessionId = lectureSessionId
        self.currentRecordingId = UUID()
        self.currentMarkers = []
        self.elapsedSeconds = 0.0

        // Destination in sandboxed recordings directory
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = docs.appendingPathComponent("Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: recordingsDir.path) {
            try? fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        let fileName = "lecture_\(currentRecordingId.uuidString).m4a"
        let destinationURL = recordingsDir.appendingPathComponent(fileName)
        self.currentRecordingUrl = destinationURL

        // Progressive stream settings: AAC Mono 44.1kHz (efficient for voice, min memory)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 64000
        ]

        let recorder = try AVAudioRecorder(url: destinationURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.prepareToRecord() else {
            throw AcademicOSError.fileSystemError("Failed to prepare AVAudioRecorder for progressive streaming.")
        }

        recorder.record()
        self.audioRecorder = recorder
        self.state = .recording

        if keepScreenAwake {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        startMeteringTimer()
    }

    public func pauseRecording() {
        guard state == .recording else { return }
        audioRecorder?.pause()
        state = .pausedByUser
        timer?.invalidate()
    }

    public func resumeRecording() {
        guard state == .pausedByUser || state == .interruptedBySystem else { return }
        do {
            try configureAudioSession()
            guard let recorder = audioRecorder, recorder.record() else {
                state = .failed("Failed to resume audio recorder.")
                return
            }
            state = .recording
            startMeteringTimer()
        } catch {
            state = .failed("Failed to reactivate audio session: \(error.localizedDescription)")
        }
    }

    public func stopRecording() -> (metadata: AudioRecordingMetadata, markers: [AudioMarker])? {
        guard state.isRecordingOrPaused else { return nil }

        timer?.invalidate()
        audioRecorder?.stop()
        state = .stopped
        UIApplication.shared.isIdleTimerDisabled = false

        guard let courseId = currentCourseId,
              let url = currentRecordingUrl else { return nil }

        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? Int64) ?? 0

        let metadata = AudioRecordingMetadata(
            id: currentRecordingId,
            courseId: courseId,
            lectureSessionId: currentSessionId ?? UUID(),
            localRelativePath: "Recordings/\(url.lastPathComponent)",
            durationSeconds: elapsedSeconds,
            fileSizeByte: fileSize,
            sampleRate: 44100.0,
            audioFormat: "m4a",
            transcriptionStatus: .notStarted,
            recordedAt: Date()
        )

        let markers = currentMarkers

        // Reset
        self.audioRecorder = nil
        self.state = .idle

        return (metadata, markers)
    }

    // MARK: - Moment Markers ("MARK IMPORTANT")
    public func markImportant(type: AudioMarkerType, note: String = "") {
        guard state == .recording || state == .pausedByUser,
              let courseId = currentCourseId else { return }

        let marker = AudioMarker(
            recordingId: currentRecordingId,
            courseId: courseId,
            lectureSessionId: currentSessionId,
            timestampSeconds: elapsedSeconds,
            markerType: type,
            noteText: note
        )
        currentMarkers.append(marker)

        // Haptic feedback for tactile confirmation
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Internal Metering & Timer
    private func startMeteringTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
            self.elapsedSeconds += 0.1
            recorder.updateMeters()

            // Average power to 0..1 scale
            let avgPower = recorder.averagePower(forChannel: 0)
            let normalized = max(0.0, min(1.0, (avgPower + 50.0) / 50.0))
            self.audioPowerLevel = normalized
        }
    }

    public nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.state = .failed("Audio recording stopped abnormally.")
            }
        }
    }
}
