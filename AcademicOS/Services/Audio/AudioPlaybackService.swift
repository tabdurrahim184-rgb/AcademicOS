import Foundation
import AVFoundation
import Combine

/// Audio playback engine allowing playback speed control, scrub seeking, and jumping to transcript timestamps.
@MainActor
public final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AudioPlaybackService()

    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var playbackRate: Float = 1.0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let fileManager = FileManager.default

    public override init() {
        super.init()
    }

    public func loadAudio(relativeFilePath: String) throws {
        stop()
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURL = docs.appendingPathComponent(relativeFilePath)

        guard fileManager.fileExists(atPath: fullURL.path) else {
            throw AcademicOSError.fileSystemError("Audio file not found at: \(relativeFilePath)")
        }

        let newPlayer = try AVAudioPlayer(contentsOf: fullURL)
        newPlayer.delegate = self
        newPlayer.enableRate = true
        newPlayer.prepareToPlay()

        self.player = newPlayer
        self.duration = newPlayer.duration
        self.currentTime = 0.0
        self.playbackRate = 1.0
    }

    public func play() {
        guard let p = player else { return }
        p.rate = playbackRate
        p.play()
        isPlaying = true
        startProgressTimer()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        progressTimer?.invalidate()
    }

    public func stop() {
        player?.stop()
        isPlaying = false
        progressTimer?.invalidate()
        currentTime = 0.0
    }

    public func seek(to time: Double) {
        guard let p = player else { return }
        let clamped = max(0.0, min(time, p.duration))
        p.currentTime = clamped
        self.currentTime = clamped
    }

    public func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let p = self.player, p.isPlaying else { return }
            self.currentTime = p.currentTime
        }
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0.0
            self.progressTimer?.invalidate()
        }
    }
}
