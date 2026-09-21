import SwiftUI

/// Minimalist empty state display consistent with Things/Notion styling.
public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color.textTertiary)

            VStack(spacing: Spacing.xxSmall) {
                Text(title)
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text(message)
                    .font(.commandSubheadline)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.large)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.commandSubheadline)
                        .foregroundColor(Color.academicPrimary)
                }
                .padding(.top, Spacing.xxSmall)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxLarge)
    }
}
