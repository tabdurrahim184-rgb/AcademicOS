import SwiftUI

/// Banner displayed at top of views when network is disconnected or limited.
/// Informs user that AcademicOS is running locally without disabling features.
public struct OfflineBanner: View {
    public let status: NetworkStatus
    public let pendingSyncCount: Int

    public init(status: NetworkStatus, pendingSyncCount: Int = 0) {
        self.status = status
        self.pendingSyncCount = pendingSyncCount
    }

    public var body: some View {
        if !status.isOnline {
            HStack(spacing: Spacing.small) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.academicAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Architecture Active")
                        .font(.commandSubheadline)
                        .foregroundColor(Color.textPrimary)

                    Text(pendingSyncCount > 0 ? "\(pendingSyncCount) jobs queued for sync • Local AI Ready" : "Local SQLite & On-Device AI operating autonomously")
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                StatusBadge("LOCAL AI", icon: "cpu", style: .emerald)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(Color.academicAmber.opacity(0.12))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.academicAmber.opacity(0.3)),
                alignment: .bottom
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
