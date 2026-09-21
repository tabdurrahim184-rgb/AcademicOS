import SwiftUI

/// Component displaying a single university announcement or urgent bulletin.
public struct UniversityAnnouncementRow: View {
    public let announcement: UniversityAnnouncement

    public init(announcement: UniversityAnnouncement) {
        self.announcement = announcement
    }

    public var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    if announcement.isUrgent {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.statusCritical)

                        Text("URGENT")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Color.statusCritical)
                    } else {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.academicPrimary)

                        Text("CAMPUS NOTICE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    Text(formatDate(announcement.announcedAt))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.textSecondary)
                }

                Text(announcement.title)
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text(announcement.body)
                    .font(.commandSubheadline)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(4)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
