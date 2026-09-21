import Foundation

/// Current operational status of an academic agent.
public enum AgentStatus: String, Codable, Sendable, CaseIterable {
    case ready = "Ready"
    case analyzing = "Analyzing"
    case synthesizing = "Synthesizing"
    case standBy = "Standby"
    case offlineLocal = "Local Mode"
}

/// Specific capability provided by an agent.
public struct AgentCapability: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String

    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Base contract for all intelligent agents in AcademicOS.
public protocol Agent: AnyObject, Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var iconName: String { get }
    var status: AgentStatus { get }
    var capabilities: [AgentCapability] { get }

    func execute(task: String, context: [String: String]) async throws -> String
}
