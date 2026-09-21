import Foundation

/// Operational readiness states for Google Gemini cloud AI.
public enum GeminiStatus: Equatable, Sendable {
    case ready
    case notConfigured
    case quotaLimited(until: Date)
    case networkOffline
    case disabledByPolicy(String)

    public var isAvailable: Bool {
        switch self {
        case .ready:
            return true
        default:
            return false
        }
    }

    public var displayTitle: String {
        switch self {
        case .ready:
            return "GEMINI READY"
        case .notConfigured:
            return "Cloud AI: Not Configured"
        case .quotaLimited:
            return "GEMINI QUOTA LIMITED"
        case .networkOffline:
            return "OFFLINE MODE"
        case .disabledByPolicy:
            return "CLOUD AI DISABLED"
        }
    }
}

/// Evaluates whether the Gemini provider can accept queries without crashing or unauthorized network calls.
public final class GeminiAvailabilityService: @unchecked Sendable {
    public static let shared = GeminiAvailabilityService()

    private let keychain: KeychainServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private var quotaCooldownUntil: Date?
    private let lock = NSLock()

    public init(
        keychain: KeychainServiceProtocol = KeychainStorage(),
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor.shared
    ) {
        self.keychain = keychain
        self.networkMonitor = networkMonitor
    }

    /// Records a 429 quota exhaustion event with an optional retry delay.
    public func recordQuotaExceeded(retryAfterSeconds: Int? = 60) {
        lock.lock()
        defer { lock.unlock() }
        let cooldown = TimeInterval(retryAfterSeconds ?? 60)
        self.quotaCooldownUntil = Date().addingTimeInterval(cooldown)
    }

    /// Resets quota limitation if any.
    public func resetQuotaStatus() {
        lock.lock()
        defer { lock.unlock() }
        self.quotaCooldownUntil = nil
    }

    /// Evaluates current Gemini availability.
    public func evaluateStatus() -> GeminiStatus {
        lock.lock()
        defer { lock.unlock() }

        // Check quota cooldown
        if let cooldown = quotaCooldownUntil {
            if Date() < cooldown {
                return .quotaLimited(until: cooldown)
            } else {
                quotaCooldownUntil = nil
            }
        }

        // Check network connection
        guard networkMonitor.isConnected else {
            return .networkOffline
        }

        // Check if Firebase configuration or Keychain key is available
        let hasGoogleServiceFile = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        let hasKeychainKey = (try? keychain.get(.geminiApiKey)) != nil

        if !hasGoogleServiceFile && !hasKeychainKey {
            return .notConfigured
        }

        return .ready
    }
}
