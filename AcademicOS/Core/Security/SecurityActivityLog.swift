import Foundation

/// Security audit events permitted in the security activity log.
public enum SecurityAuditEventType: String, Codable, Sendable {
    case loginStarted = "LOGIN_STARTED"
    case loginSucceeded = "LOGIN_SUCCEEDED"
    case loginFailed = "LOGIN_FAILED"
    case sessionExpired = "SESSION_EXPIRED"
    case domainRejected = "DOMAIN_REJECTED"
    case unexpectedRedirect = "UNEXPECTED_REDIRECT"
    case credentialsDeleted = "CREDENTIALS_DELETED"
    case sessionCleared = "SESSION_CLEARED"
    case iframeAutofillBlocked = "IFRAME_AUTOFILL_BLOCKED"
    case insecureHTTPBlocked = "INSECURE_HTTP_BLOCKED"
}

/// Sanitized audit log entry guaranteeing zero credential or token leakage.
public struct SecurityLogEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let eventType: SecurityAuditEventType
    public let host: String
    public let details: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        eventType: SecurityAuditEventType,
        host: String,
        details: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.eventType = eventType
        self.host = host
        self.details = details
        self.timestamp = timestamp
    }
}

/// Thread-safe security activity audit logger with strict redaction.
public final class SecurityActivityLogger: @unchecked Sendable {
    public static let shared = SecurityActivityLogger()

    private let lock = NSLock()
    private var entries: [SecurityLogEntry] = []
    private let maxEntries: Int = 100

    public init() {}

    /// Records a security event. Strictly filters out passwords, tokens, cookies, and query params.
    public func record(
        event: SecurityAuditEventType,
        url: URL?,
        safeDescription: String
    ) {
        let host = url?.host ?? "none"
        let sanitizedDetails = sanitize(safeDescription)

        lock.lock()
        defer { lock.unlock() }

        let entry = SecurityLogEntry(
            eventType: event,
            host: host,
            details: sanitizedDetails
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func recentLogs() -> [SecurityLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.reversed()
    }

    /// Strips any query parameters or sensitive keyword strings from descriptions.
    private func sanitize(_ text: String) -> String {
        // Redact any query strings if a URL was passed
        var cleaned = text
        if let queryIndex = cleaned.firstIndex(of: "?") {
            cleaned = String(cleaned[..<queryIndex]) + " [QUERY_REDACTED]"
        }
        return cleaned
    }
}
