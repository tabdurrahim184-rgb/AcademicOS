import Foundation

/// Comprehensive typed errors across AcademicOS subsystems.
public enum AcademicOSError: LocalizedError, Sendable, Equatable {
    case databaseError(String)
    case entityNotFound(String)
    case networkUnavailable
    case aiProviderUnavailable(String)
    case keychainError(status: Int32, message: String)
    case serializationError(String)
    case offlineQueueFull
    case invalidInput(String)
    case unauthorized
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database Error: \(message)"
        case .entityNotFound(let entity):
            return "Entity Not Found: \(entity)"
        case .networkUnavailable:
            return "Network connection is offline. Action queued for sync."
        case .aiProviderUnavailable(let provider):
            return "AI Provider \(provider) is currently unreachable. Switched to local mode."
        case .keychainError(let status, let message):
            return "Keychain Security Error [\(status)]: \(message)"
        case .serializationError(let details):
            return "Data Serialization Error: \(details)"
        case .offlineQueueFull:
            return "Offline job queue has exceeded capacity."
        case .invalidInput(let reason):
            return "Invalid Input: \(reason)"
        case .unauthorized:
            return "Access denied or biometric challenge failed."
        case .fileSystemError(let details):
            return "File System Error: \(details)"
        }
    }
}
