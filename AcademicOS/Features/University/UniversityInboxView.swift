import SwiftUI

/// Unified inbox view displaying university notifications, announcements, exams, and grades.
public struct UniversityInboxView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var inboxItems: [UniversityInboxItem] = []
    @State private var selectedCategory: UniversityInboxCategory? = nil
    @State private var isLoading: Bool = false

    public init() {}

    private var filteredItems: [UniversityInboxItem] {
        if let cat = selectedCategory {
            return inboxItems.filter { $0.category == cat }
        }
        return inboxItems
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(UniversityInboxCategory.allCases, id: \.self) { cat in
                        FilterChip(
                            title: cat.rawValue,
                            isSelected: selectedCategory == cat,
                            action: { selectedCategory = cat }
                        )
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
            }
            .background(Color(uiColor: .secondarySystemBackground))

            // Items List
            if filteredItems.isEmpty {
                VStack(spacing: Spacing.medium) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.textSecondary.opacity(0.4))
                    Text("University Inbox is Clean")
                        .font(.commandHeadline)
                        .foregroundColor(Color.textSecondary)
                    Text("No unread announcements or alerts from your university portal.")
                        .font(.commandSubheadline)
                        .foregroundColor(Color.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xLarge)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        inboxRow(item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                Task {
                                    try? await container.universityRepository.markInboxItemAsRead(id: item.id)
                                    await loadInbox()
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("University Inbox")
        .task {
            await loadInbox()
        }
        .refreshable {
            await loadInbox()
        }
    }

    private func inboxRow(_ item: UniversityInboxItem) -> some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: item.isRead ? Color(uiColor: .secondarySystemBackground) : Color.academicPrimary.opacity(0.08)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(alignment: .top) {
                    if !item.isRead {
                        Circle()
                            .fill(Color.academicPrimary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.sender)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.academicPrimary)

                            Spacer()

                            Text(formatTime(item.receivedAt))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.textSecondary)
                        }

                        Text(item.title)
                            .font(.commandHeadline)
                            .foregroundColor(Color.textPrimary)

                        Text(item.content)
                            .font(.commandSubheadline)
                            .foregroundColor(Color.textSecondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func loadInbox() async {
        isLoading = true
        inboxItems = (try? await container.universityRepository.fetchInboxItems()) ?? []
        isLoading = false
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
