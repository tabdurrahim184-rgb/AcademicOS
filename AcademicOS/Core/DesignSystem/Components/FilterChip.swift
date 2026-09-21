import SwiftUI

/// Semantic filter chip for horizontal tag and category filtering.
public struct FilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.xSmall)
                .foregroundColor(isSelected ? .white : Color.textSecondary)
                .background(isSelected ? Color.academicPrimary : Color.textSecondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
