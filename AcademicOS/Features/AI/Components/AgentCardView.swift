import SwiftUI

/// Card displaying an AI Agent with its operational status, description, and capability tags.
public struct AgentCardView: View {
    public let agent: Agent
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(agent: Agent, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.agent = agent
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            borderColor: isSelected ? Color.academicPrimary : nil,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                // Header: Icon, Name, Status
                HStack(alignment: .top) {
                    Image(systemName: agent.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.academicPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.academicPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name)
                            .font(.commandHeadline)
                            .foregroundColor(Color.textPrimary)

                        Text(agent.id)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.textTertiary)
                    }

                    Spacer()

                    StatusBadge(agent.status.rawValue.uppercased(), icon: "circle.fill", style: .emerald)
                }

                // Description
                Text(agent.description)
                    .font(.commandSubheadline)
                    .foregroundColor(Color.textSecondary)

                Divider()
                    .background(Color.borderSubtle)

                // Capabilities
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("CAPABILITIES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.textTertiary)

                    FlowLayout(spacing: Spacing.xxSmall) {
                        ForEach(agent.capabilities) { capability in
                            HStack(spacing: Spacing.xxxSmall) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 8))
                                Text(capability.name)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, Spacing.small)
                            .padding(.vertical, Spacing.xxxSmall)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .foregroundColor(Color.textPrimary)
                            .clipShape(Capsule())
                        }
                    }
                }

                // Selection / Activation button
                Button(action: onSelect) {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "play.circle")
                            .font(.system(size: 13))
                        Text(isSelected ? "Active Target Agent" : "Select for Task")
                            .font(.commandSubheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xSmall)
                    .background(isSelected ? Color.academicPrimary.opacity(0.15) : Color(uiColor: .tertiarySystemBackground))
                    .foregroundColor(isSelected ? Color.academicPrimary : Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xxSmall)
            }
        }
    }
}

/// Simple flow layout helper for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
