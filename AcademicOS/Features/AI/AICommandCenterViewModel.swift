import SwiftUI
import Combine

/// State management for the AI Command Center.
@MainActor
public final class AICommandCenterViewModel: ObservableObject {
    @Published public var agents: [Agent] = []
    @Published public var selectedAgent: Agent?
    @Published public var promptInput: String = ""
    @Published public var executionResult: String?
    @Published public var isExecuting: Bool = false
    @Published public var errorMessage: String?

    private let coordinator: AgentCoordinatorProtocol
    private let router: AIRouterProtocol

    public init(coordinator: AgentCoordinatorProtocol, router: AIRouterProtocol) {
        self.coordinator = coordinator
        self.router = router
    }

    public func loadAgents() {
        self.agents = coordinator.allAgents()
        if selectedAgent == nil {
            self.selectedAgent = agents.first
        }
    }

    public func executePrompt() async {
        guard let agent = selectedAgent, !promptInput.isEmpty else { return }
        isExecuting = true
        errorMessage = nil
        executionResult = nil

        let taskText = promptInput
        promptInput = ""

        do {
            let result = try await coordinator.executeTask(
                agentId: agent.id,
                task: taskText,
                context: ["active_session": "academic_os_dashboard"]
            )
            self.executionResult = result
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isExecuting = false
    }
}
