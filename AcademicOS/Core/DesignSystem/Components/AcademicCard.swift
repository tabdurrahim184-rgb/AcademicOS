import SwiftUI

/// Premium card container with Apple-native rounded borders, background, and elevation.
public struct AcademicCard<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let borderColor: Color?
    private let backgroundColor: Color

    public init(
        cornerRadius: CGFloat = CornerRadius.large,
        padding: CGFloat = Spacing.medium,
        borderColor: Color? = nil,
        backgroundColor: Color = Color(uiColor: .secondarySystemBackground),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor ?? Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
            )
            .academicCardShadow()
    }
}
