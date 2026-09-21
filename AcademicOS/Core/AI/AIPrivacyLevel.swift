import Foundation

/// Defines privacy sensitivity tiers for AI processing.
public enum AIPrivacyLevel: String, Codable, Sendable {
    /// Strictly on-device. Must never transmit network packets to cloud models.
    case localOnly = "LOCAL_ONLY"
    /// May utilize Gemini cloud reasoning according to user and course settings.
    case cloudAllowed = "CLOUD_ALLOWED"
    /// Contains credentials, tokens, or private secrets. Forbidden from cloud transmission.
    case sensitive = "SENSITIVE"

    public var allowsCloudAI: Bool {
        return self == .cloudAllowed
    }
}

/// Helper that inspects and sanitizes prompts to guarantee sensitive credentials never leave the device.
public struct AIPrivacySanitizer: Sendable {
    private static let sensitivePatterns = [
        "(?i)password\\s*[:=]\\s*\\S+",
        "(?i)token\\s*[:=]\\s*\\S+",
        "(?i)cookie\\s*[:=]\\s*\\S+",
        "(?i)api[_-]?key\\s*[:=]\\s*\\S+",
        "(?i)bearer\\s+[A-Za-z0-9\\-_\\.]+",
        "(?i)keychain\\s*[:=]\\s*\\S+",
        "(?i)lms[_-]?pass\\s*[:=]\\s*\\S+"
    ]

    /// Returns true if prompt text contains known sensitive patterns.
    public static func containsSensitiveContent(_ text: String) -> Bool {
        for pattern in sensitivePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Redacts sensitive patterns from prompt text.
    public static func sanitize(_ text: String) -> String {
        var sanitized = text
        for pattern in sensitivePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "[REDACTED_SECRET]", options: .regularExpression)
        }
        return sanitized
    }
}
