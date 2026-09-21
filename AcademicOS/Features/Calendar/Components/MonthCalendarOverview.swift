import SwiftUI

/// Month overview widget showing days of the current month with active event dots.
public struct MonthCalendarOverview: View {
    @Binding public var selectedDate: Date
    public let events: [CalendarUnifiedEvent]

    public init(selectedDate: Binding<Date>, events: [CalendarUnifiedEvent]) {
        self._selectedDate = selectedDate
        self.events = events
    }

    private let calendar = Calendar.current
    private let daysInWeek = ["M", "T", "W", "T", "F", "S", "S"]

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(spacing: Spacing.small) {
                // Month & Year title
                HStack {
                    Text(monthYearString)
                        .font(.commandHeadline)
                        .foregroundColor(Color.textPrimary)

                    Spacer()

                    StatusBadge("EXAM SEASON", style: .crimson)
                }

                // Days of week header
                HStack {
                    ForEach(0..<7, id: \.self) { index in
                        Text(daysInWeek[index])
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                Divider()
                    .background(Color.borderSubtle)

                // Current Week Quick Selector
                HStack {
                    ForEach(0..<7, id: \.self) { offset in
                        let dayDate = calendar.date(byAdding: .day, value: offset - 3, to: selectedDate) ?? selectedDate
                        let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
                        let dayNumber = calendar.component(.day, from: dayDate)

                        VStack(spacing: Spacing.xxSmall) {
                            Text("\(dayNumber)")
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .monospaced))
                                .foregroundColor(isSelected ? Color.white : Color.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(isSelected ? Color.academicPrimary : Color.clear)
                                .clipShape(Circle())

                            // Event dot
                            Circle()
                                .fill(hasEvents(on: dayDate) ? Color.academicCyan : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            selectedDate = dayDate
                        }
                    }
                }
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private func hasEvents(on date: Date) -> Bool {
        return events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
