import SwiftUI

/// Compact data card displaying a key numeric academic metric.
public struct MetricBadge: View {
    public let label: String
    public let value: String
    public let icon: String
    public let accentColor: Color

    public init(
        label: String,
        value: String,
        icon: String,
        accentColor: Color = Color.academicPrimary
    ) {
        self.label = label
        self.value = value
        self.icon = icon
        self.accentColor = accentColor
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.small,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                    Spacer()
                }

                Text(value)
                    .font(.metricLarge)
                    .foregroundColor(Color.textPrimary)

                Text(label)
                    .font(.commandCaption)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
