import Foundation

/// Specific errors that can occur during cloud or local AI inference.
public enum AIProviderError: Error, LocalizedError, Equatable, Sendable {
    case notConfigured
    case quotaExceeded(retryAfterSeconds: Int?)
    case temporaryServiceUnavailable(String)
    case networkError(String)
    case invalidConfiguration(String)
    case appCheckRejection(String)
    case modelUnavailable(String)
    case responseBlocked(reason: String)
    case malformedStructuredResponse(String)
    case privacyRestricted(String)
    case generalError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud AI (Gemini) is not configured. Falling back to local offline reasoning."
        case .quotaExceeded(let retry):
            if let seconds = retry {
                return "Gemini Developer API rate limit reached (429). Retry in \(seconds)s. Switched to Local AI."
            } else {
                return "Gemini Developer API free quota reached (429). Switched to Local AI."
            }
        case .temporaryServiceUnavailable(let msg):
            return "AI service temporarily unavailable: \(msg)"
        case .networkError(let msg):
            return "Network connection failed: \(msg)"
        case .invalidConfiguration(let msg):
            return "Invalid AI configuration: \(msg)"
        case .appCheckRejection(let msg):
            return "Firebase App Check verification failed: \(msg)"
        case .modelUnavailable(let model):
            return "Requested AI model '\(model)' is not available."
        case .responseBlocked(let reason):
            return "AI generation was blocked by safety filters: \(reason)"
        case .malformedStructuredResponse(let msg):
            return "Failed to parse structured AI output: \(msg)"
        case .privacyRestricted(let msg):
            return "Operation blocked by course or global privacy settings: \(msg)"
        case .generalError(let msg):
            return "AI error: \(msg)"
        }
    }

    public var isRetryableWithLocalFallback: Bool {
        switch self {
        case .quotaExceeded, .temporaryServiceUnavailable, .networkError, .appCheckRejection, .notConfigured:
            return true
        default:
            return false
        }
    }
}
