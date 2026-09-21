import Foundation

/// Capability detection status for a specific university portal feature.
public enum CapabilityDetectionStatus: String, Codable, Sendable {
    case detected = "Detected"
    case failed = "Failed"
    case notConfigured = "Not Configured"
}

/// Single capability diagnostic report item.
public struct CapabilityDiagnosticItem: Identifiable, Codable, Sendable, Equatable {
    public var id: String { capabilityName }
    public let capabilityName: String
    public let status: CapabilityDetectionStatus
    public let itemsFoundCount: Int
    public let safeDiagnosticMessage: String

    public init(
        capabilityName: String,
        status: CapabilityDetectionStatus,
        itemsFoundCount: Int = 0,
        safeDiagnosticMessage: String
    ) {
        self.capabilityName = capabilityName
        self.status = status
        self.itemsFoundCount = itemsFoundCount
        self.safeDiagnosticMessage = safeDiagnosticMessage
    }
}

/// Comprehensive diagnostics report for university portal connectors.
/// Evaluates whether selectors and semantic parsers successfully extract data.
/// STRICTLY does NOT display cookies, tokens, passwords, or PII.
public struct UniversityConnectorDiagnostics: Codable, Sendable, Equatable {
    public let portalName: String
    public let timestamp: Date
    public let items: [CapabilityDiagnosticItem]

    public init(
        portalName: String,
        timestamp: Date = Date(),
        items: [CapabilityDiagnosticItem]
    ) {
        self.portalName = portalName
        self.timestamp = timestamp
        self.items = items
    }

    public var overallSuccess: Bool {
        // At least courses and one other capability detected
        let coursesDetected = items.first(where: { $0.capabilityName == "COURSES" })?.status == .detected
        let detectedCount = items.filter { $0.status == .detected }.count
        return coursesDetected && detectedCount >= 2
    }
}
