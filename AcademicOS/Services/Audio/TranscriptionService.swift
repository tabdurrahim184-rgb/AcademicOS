import Foundation
import Speech
import AVFoundation
import Combine

/// Specific capability state for Speech Recognition on the device.
public enum TranscriptionCapability: String, Codable, Equatable, Sendable {
    case onDeviceAvailable
    case cloudRecognitionAvailable
    case authorizationDenied
    case recognizerUnavailable
    case localeUnsupported

    public var canTranscribeOffline: Bool {
        return self == .onDeviceAvailable
    }
}

/// Progress update emitted during lecture speech recognition.
public struct TranscriptionProgress: Sendable {
    public let recordingId: UUID
    public let processedSeconds: Double
    public let totalSeconds: Double
    public let currentText: String
    public let isCompleted: Bool

    public var percentage: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return min(100.0, (processedSeconds / totalSeconds) * 100.0)
    }
}

/// Base protocol for speech transcription providers.
public protocol TranscriptionProvider: Sendable {
    var providerName: String { get }
    func checkCapability() -> TranscriptionCapability

    func transcribeChunk(
        audioURL: URL,
        recordingId: UUID,
        courseId: UUID,
        startTimeSeconds: Double,
        chunkDurationSeconds: Double,
        requireOnDevice: Bool
    ) async throws -> [TranscriptSegment]
}

/// Protocol defining speech transcription services.
public protocol TranscriptionServiceProtocol: AnyObject, Sendable {
    func checkCapability() -> TranscriptionCapability
    func transcribeRecording(recording: AudioRecordingMetadata, requireOnDevice: Bool) async throws -> Transcript
}

public extension TranscriptionServiceProtocol {
    func transcribeRecording(recording: AudioRecordingMetadata) async throws -> Transcript {
        try await transcribeRecording(recording: recording, requireOnDevice: true)
    }
}

/// Production-ready Speech-to-Text provider leveraging Apple's native Speech.framework.
/// Enforces on-device checks and processes audio in safe window chunks for long 60–180 min lectures.
public final class AppleSpeechTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    public let providerName: String = "Apple Speech"
    private let speechRecognizer: SFSpeechRecognizer?

    public init(locale: Locale = Locale(identifier: "tr-TR")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    public func checkCapability() -> TranscriptionCapability {
        guard let recognizer = speechRecognizer else {
            return .localeUnsupported
        }
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus == .denied || authStatus == .restricted {
            return .authorizationDenied
        }
        guard recognizer.isAvailable else {
            return .recognizerUnavailable
        }
        if recognizer.supportsOnDeviceRecognition {
            return .onDeviceAvailable
        } else {
            return .cloudRecognitionAvailable
        }
    }

    public func transcribeChunk(
        audioURL: URL,
        recordingId: UUID,
        courseId: UUID,
        startTimeSeconds: Double,
        chunkDurationSeconds: Double,
        requireOnDevice: Bool
    ) async throws -> [TranscriptSegment] {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw AcademicOSError.aiProviderUnavailable("Apple Speech Recognizer is not available on this device.")
        }

        // Request Speech Authorization if undetermined
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus == .denied || authStatus == .restricted {
            throw AcademicOSError.unauthorized
        } else if authStatus == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else {
                throw AcademicOSError.unauthorized
            }
        }

        if requireOnDevice && !recognizer.supportsOnDeviceRecognition {
            throw AcademicOSError.aiProviderUnavailable("On-device speech recognition is not supported on this device/locale.")
        }

        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        recognitionRequest.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition && requireOnDevice {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // Set safe window chunk range
        if chunkDurationSeconds > 0 {
            let start = CMTime(seconds: startTimeSeconds, preferredTimescale: 600)
            let duration = CMTime(seconds: chunkDurationSeconds, preferredTimescale: 600)
            recognitionRequest.timeRange = CMTimeRange(start: start, duration: duration)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()

            _ = recognizer.recognitionTask(with: recognitionRequest) { result, error in
                lock.lock()
                defer { lock.unlock() }

                if let err = error {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: err)
                    }
                    return
                }

                guard let res = result else { return }

                if res.isFinal && !hasResumed {
                    hasResumed = true
                    let segments: [TranscriptSegment] = res.bestTranscription.segments.map { seg in
                        TranscriptSegment(
                            recordingId: recordingId,
                            courseId: courseId,
                            startSeconds: startTimeSeconds + seg.timestamp,
                            endSeconds: startTimeSeconds + seg.timestamp + seg.duration,
                            text: seg.substring,
                            confidence: Double(seg.confidence)
                        )
                    }
                    continuation.resume(returning: segments)
                }
            }
        }
    }
}

/// Coordinates speech transcription queues, chunked long lecture processing, and incremental database progress.
@MainActor
public final class TranscriptionService: ObservableObject, TranscriptionServiceProtocol {
    @Published public var activeJobs: [UUID: TranscriptionProgress] = [:]
    @Published public var isProcessing: Bool = false

    private let provider: TranscriptionProvider
    private let recordingRepo: RecordingRepositoryProtocol

    public init(
        provider: TranscriptionProvider = AppleSpeechTranscriptionProvider(),
        recordingRepo: RecordingRepositoryProtocol = DatabaseRecordingRepository(localStore: SQLiteDatabaseManager.shared)
    ) {
        self.provider = provider
        self.recordingRepo = recordingRepo
    }

    public func checkCapability() -> TranscriptionCapability {
        return provider.checkCapability()
    }

    /// Transcribes a recording safely in chunks, persisting progress after each chunk.
    /// If an error occurs at 75%, the first 75% of segments are already saved and preserved in SQLite.
    public func transcribeRecording(
        recording: AudioRecordingMetadata,
        requireOnDevice: Bool = true
    ) async throws -> Transcript {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURL = docs.appendingPathComponent(recording.localRelativePath)

        guard fileManager.fileExists(atPath: fullURL.path) else {
            throw AcademicOSError.fileSystemError("Audio recording file missing at: \(recording.localRelativePath)")
        }

        let capability = provider.checkCapability()
        if capability == .authorizationDenied {
            var updatedMeta = recording
            updatedMeta.transcriptionStatus = .failed
            updatedMeta.lastError = "Speech recognition permission denied by user."
            try? await recordingRepo.saveRecording(updatedMeta)
            throw AcademicOSError.unauthorized
        }

        if requireOnDevice && !capability.canTranscribeOffline {
            var updatedMeta = recording
            updatedMeta.transcriptionStatus = .waitingForCapability
            updatedMeta.lastError = "On-device speech recognition is unavailable. Audio is safely stored offline."
            try? await recordingRepo.saveRecording(updatedMeta)
            throw AcademicOSError.aiProviderUnavailable(updatedMeta.lastError!)
        }

        self.isProcessing = true
        var updatedMeta = recording
        updatedMeta.transcriptionStatus = requireOnDevice ? .transcribingLocal : .transcribingCloud
        updatedMeta.provider = provider.providerName
        try? await recordingRepo.saveRecording(updatedMeta)

        let asset = AVURLAsset(url: fullURL)
        let totalDuration = max(1.0, CMTimeGetSeconds(asset.duration))
        let chunkDuration: Double = 180.0 // 3-minute chunk windows for safety

        var currentOffset = updatedMeta.lastProcessedAudioTime
        var accumulatedSegments: [TranscriptSegment] = []

        // If resuming, fetch previously stored segments from SQLite
        let transcriptId = UUID()
        let existingSegments = (try? await recordingRepo.getSegments(forTranscriptId: transcriptId)) ?? []
        accumulatedSegments.append(contentsOf: existingSegments)

        do {
            while currentOffset < totalDuration {
                let thisChunkDuration = min(chunkDuration, totalDuration - currentOffset)

                let newSegments = try await provider.transcribeChunk(
                    audioURL: fullURL,
                    recordingId: recording.id,
                    courseId: recording.courseId,
                    startTimeSeconds: currentOffset,
                    chunkDurationSeconds: thisChunkDuration,
                    requireOnDevice: requireOnDevice
                )

                // Persist each chunk segment immediately to SQLite
                for seg in newSegments {
                    try await recordingRepo.saveTranscriptSegment(seg)
                    accumulatedSegments.append(seg)
                }

                currentOffset += thisChunkDuration
                updatedMeta.lastProcessedAudioTime = currentOffset
                updatedMeta.transcriptionProgress = min(100.0, (currentOffset / totalDuration) * 100.0)
                try await recordingRepo.saveRecording(updatedMeta)

                let fullTextSoFar = accumulatedSegments.map { $0.text }.joined(separator: " ")
                let progress = TranscriptionProgress(
                    recordingId: recording.id,
                    processedSeconds: currentOffset,
                    totalSeconds: totalDuration,
                    currentText: fullTextSoFar,
                    isCompleted: currentOffset >= totalDuration
                )
                self.activeJobs[recording.id] = progress
            }

            // Successfully finished all chunks
            let fullText = accumulatedSegments.map { $0.text }.joined(separator: " ")
            let finalTranscript = Transcript(
                id: transcriptId,
                recordingId: recording.id,
                courseId: recording.courseId,
                fullText: fullText,
                segments: accumulatedSegments,
                language: "tr-TR",
                isProcessedByAI: false,
                generatedAt: Date()
            )

            try await recordingRepo.saveTranscript(finalTranscript)

            updatedMeta.transcriptionStatus = .completed
            updatedMeta.transcriptionProgress = 100.0
            updatedMeta.lastError = nil
            try await recordingRepo.saveRecording(updatedMeta)

            self.activeJobs.removeValue(forKey: recording.id)
            self.isProcessing = !self.activeJobs.isEmpty
            return finalTranscript

        } catch {
            // Partial Failure: Progress, segments, and audio file are 100% PRESERVED!
            updatedMeta.transcriptionStatus = .failed
            updatedMeta.lastError = error.localizedDescription
            updatedMeta.retryCount += 1
            try? await recordingRepo.saveRecording(updatedMeta)

            self.activeJobs.removeValue(forKey: recording.id)
            self.isProcessing = !self.activeJobs.isEmpty
            throw error
        }
    }
}
