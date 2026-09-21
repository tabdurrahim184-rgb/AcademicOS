import Foundation

/// Defines the level of trust and provenance for academic portal records.
public enum PortalDataTrustLevel: String, Codable, Sendable, CaseIterable {
    /// Deterministically extracted from official university APIs or structured tables.
    case officialPortal = "Official Portal"

    /// Parsed from standard university portal HTML/DOM with high confidence.
    case parsedPortal = "Parsed Portal"

    /// Explicitly reviewed and confirmed by the student.
    case userConfirmed = "User Confirmed"

    /// Heuristically inferred from schedule patterns or course context.
    case inferred = "Inferred"

    /// Extracted by AI language models from unstructured text; requires confirmation if ambiguous.
    case aiExtracted = "AI Extracted"

    /// Whether the data requires explicit user review before being treated as an official academic deadline.
    public var requiresUserConfirmation: Bool {
        switch self {
        case .officialPortal, .userConfirmed:
            return false
        case .parsedPortal:
            return false
        case .inferred, .aiExtracted:
            return true
        }
    }

    /// Visual badge color style name.
    public var badgeStyle: String {
        switch self {
        case .officialPortal: return "emerald"
        case .userConfirmed: return "indigo"
        case .parsedPortal: return "cyan"
        case .inferred: return "amber"
        case .aiExtracted: return "purple"
        }
    }
}
