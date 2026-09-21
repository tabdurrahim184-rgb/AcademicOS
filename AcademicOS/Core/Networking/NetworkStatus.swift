import Foundation

/// Represents the network connectivity state of the application.
public enum NetworkStatus: Equatable, Sendable {
    case online
    case offline
    case limited(reason: String)

    public var isOnline: Bool {
        if case .online = self { return true }
        return false
    }

    public var displayTitle: String {
        switch self {
        case .online:
            return "Online"
        case .offline:
            return "Offline (Local Mode)"
        case .limited(let reason):
            return "Limited: \(reason)"
        }
    }
}
