import SwiftUI

/// Schedule item row displaying date, badge, title, and metadata.
public struct EventScheduleRow: View {
    public let event: CalendarUnifiedEvent

    public init(event: CalendarUnifiedEvent) {
        self.event = event
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            HStack(spacing: Spacing.medium) {
                // Category color pill
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.color)
                    .frame(width: 4, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Spacing.xxSmall) {
                        Text(event.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(event.color)

                        Text("• \(dayFormatter.string(from: event.date))")
                            .font(.commandCaption)
                            .foregroundColor(Color.textSecondary)
                    }

                    Text(event.title)
                        .font(.commandHeadline)
                        .foregroundColor(Color.textPrimary)

                    Text(event.subtitle)
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                Text(timeFormatter.string(from: event.date))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
            }
        }
    }
}
