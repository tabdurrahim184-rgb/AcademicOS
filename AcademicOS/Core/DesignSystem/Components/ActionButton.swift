import SwiftUI

/// Premium tactility button conforming to Apple HIG with command-center styling.
public struct ActionButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
    }

    public let title: String
    public let icon: String?
    public let style: Style
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return Color.white
        case .secondary: return Color.textPrimary
        case .destructive: return Color.white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return Color.academicPrimary
        case .secondary: return Color(uiColor: .tertiarySystemBackground)
        case .destructive: return Color.academicCrimson
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.commandHeadline)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(style == .secondary ? Color.borderSubtle : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Tactile bounce button style
public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
