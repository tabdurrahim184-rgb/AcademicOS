import SwiftUI

/// Command center displaying registered agents, dynamic routing status, and prompt dispatch console.
public struct AICommandCenterView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: AICommandCenterViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: AICommandCenterViewModel(
            coordinator: AppContainer.shared.agentCoordinator,
            router: AppContainer.shared.aiRouter
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Router Status Banner
                AIRouterStatusBanner(
                    activeType: container.activeAIProviderType,
                    isOnline: container.networkStatus.isOnline
                )

                // Dispatch Console (Prompt input to active agent)
                agentConsole

                // Agent Registry Title & List
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("AGENT REGISTRY (\(viewModel.agents.count))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textSecondary)
                            .tracking(1.0)

                        Spacer()

                        StatusBadge("EXPANDABLE", style: .cyan)
                    }

                    VStack(spacing: Spacing.medium) {
                        ForEach(viewModel.agents, id: \.id) { agent in
                            AgentCardView(
                                agent: agent,
                                isSelected: viewModel.selectedAgent?.id == agent.id,
                                onSelect: {
                                    viewModel.selectedAgent = agent
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xxxLarge)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("AI Command Center")
        .task {
            viewModel.loadAgents()
        }
    }

    private var agentConsole: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundColor(Color.academicPrimary)

                    Text("TARGET: \(viewModel.selectedAgent?.name.uppercased() ?? "AGENT")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.textPrimary)

                    Spacer()

                    if viewModel.isExecuting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                TextField("Enter mission prompt or academic instruction...", text: $viewModel.promptInput)
                    .font(.commandBody)
                    .padding(Spacing.small)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                ActionButton(
                    viewModel.isExecuting ? "Executing Reasoning Engine..." : "Dispatch to Agent",
                    icon: "arrow.up.circle.fill",
                    style: .primary
                ) {
                    Task {
                        await viewModel.executePrompt()
                    }
                }
                .disabled(viewModel.promptInput.isEmpty || viewModel.isExecuting)

                if let result = viewModel.executionResult {
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text("EXECUTION OUTPUT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.academicEmerald)

                        Text(result)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                            .padding(Spacing.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .padding(.top, Spacing.xxSmall)
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.commandCaption)
                        .foregroundColor(Color.academicCrimson)
                }
            }
        }
    }
}
