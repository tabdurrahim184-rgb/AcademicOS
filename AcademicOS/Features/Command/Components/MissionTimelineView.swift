import SwiftUI

/// Timeline list showing today's sequential academic missions with completion toggles.
public struct MissionTimelineView: View {
    public let missions: [AcademicTask]
    public let onToggle: (UUID) -> Void

    public init(missions: [AcademicTask], onToggle: @escaping (UUID) -> Void) {
        self.missions = missions
        self.onToggle = onToggle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Text("TODAY'S MISSION")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                Spacer()

                let completed = missions.filter { $0.isCompleted }.count
                Text("\(completed)/\(missions.count) Cleared")
                    .font(.commandCaption)
                    .foregroundColor(Color.academicEmerald)
            }

            AcademicCard(
                cornerRadius: CornerRadius.large,
                padding: Spacing.small,
                backgroundColor: Color(uiColor: .secondarySystemBackground)
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(missions.enumerated()), id: \.element.id) { index, mission in
                        HStack(spacing: Spacing.medium) {
                            // Checkbox
                            Button(action: {
                                onToggle(mission.id)
                            }) {
                                Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(mission.isCompleted ? Color.academicEmerald : Color.textTertiary)
                            }
                            .buttonStyle(.plain)

                            // Title & schedule
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mission.title)
                                    .font(.commandHeadline)
                                    .foregroundColor(mission.isCompleted ? Color.textSecondary : Color.textPrimary)
                                    .strikethrough(mission.isCompleted, color: Color.textSecondary)

                                if let time = mission.scheduledTime {
                                    HStack(spacing: Spacing.xxSmall) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 10))
                                        Text(time)
                                            .font(.commandCaption)
                                    }
                                    .foregroundColor(Color.textSecondary)
                                }
                            }

                            Spacer()

                            // Priority Indicator
                            if mission.priority == .urgent {
                                StatusBadge("CRITICAL", icon: "exclamationmark.triangle.fill", style: .crimson)
                            } else if mission.isCompleted {
                                StatusBadge("CLEARED", style: .emerald)
                            }
                        }
                        .padding(.vertical, Spacing.small)
                        .padding(.horizontal, Spacing.xxSmall)

                        if index < missions.count - 1 {
                            Divider()
                                .background(Color.borderSubtle)
                        }
                    }
                }
            }
        }
    }
}
