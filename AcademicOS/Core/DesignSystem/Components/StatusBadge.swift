import SwiftUI

/// Distinct semantic badge showing operational states (AI status, priority, sync).
public struct StatusBadge: View {
    public enum Style {
        case emerald
        case indigo
        case amber
        case crimson
        case cyan
        case neutral
    }

    public let title: String
    public let icon: String?
    public let style: Style

    public init(_ title: String, icon: String? = nil, style: Style = .neutral) {
        self.title = title
        self.icon = icon
        self.style = style
    }

    private var foregroundColor: Color {
        switch style {
        case .emerald: return Color.academicEmerald
        case .indigo: return Color.academicPrimary
        case .amber: return Color.academicAmber
        case .crimson: return Color.academicCrimson
        case .cyan: return Color.academicCyan
        case .neutral: return Color.textSecondary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    public var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.xxSmall)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(foregroundColor.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// Global alias for semantic status badge styles.
public typealias StatusBadgeStyle = StatusBadge.Style
