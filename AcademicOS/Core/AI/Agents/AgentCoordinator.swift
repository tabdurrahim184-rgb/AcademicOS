import Foundation
import Combine

/// Protocol for registering and querying agents dynamically across the OS.
public protocol AgentCoordinatorProtocol: AnyObject, Sendable {
    func register(agent: Agent)
    func unregister(agentId: String)
    func agent(withId id: String) -> Agent?
    func allAgents() -> [Agent]
    func executeTask(agentId: String, task: String, context: [String: String]) async throws -> String
}

/// Central coordinator that discovers, registers, and routes operations to specialized agents.
/// Designed for limitless future expansion (e.g. Thesis Agent, Research Agent).
public final class AgentCoordinator: AgentCoordinatorProtocol, @unchecked Sendable {
    private var registry: [String: Agent] = [:]
    private let lock = NSLock()
    private let router: AIRouterProtocol

    public init(router: AIRouterProtocol) {
        self.router = router
    }

    public func register(agent: Agent) {
        lock.lock()
        defer { lock.unlock() }
        registry[agent.id] = agent
    }

    public func unregister(agentId: String) {
        lock.lock()
        defer { lock.unlock() }
        registry.removeValue(forKey: agentId)
    }

    public func agent(withId id: String) -> Agent? {
        lock.lock()
        defer { lock.unlock() }
        return registry[id]
    }

    public func allAgents() -> [Agent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(registry.values).sorted { $0.name < $1.name }
    }

    public func executeTask(agentId: String, task: String, context: [String: String]) async throws -> String {
        guard let agent = agent(withId: agentId) else {
            throw AcademicOSError.entityNotFound("Agent with id '\(agentId)' is not registered.")
        }
        return try await agent.execute(task: task, context: context)
    }
}
