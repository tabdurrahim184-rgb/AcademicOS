import SwiftUI

/// Enhanced AI status banner displaying 7 distinct readiness states with tap-to-explain details.
public struct AIRouterStatusBanner: View {
    public let activeType: AIProviderType
    public let isOnline: Bool

    @State private var showingDetailsSheet: Bool = false

    public init(activeType: AIProviderType, isOnline: Bool) {
        self.activeType = activeType
        self.isOnline = isOnline
    }

    private var currentStatusKey: String {
        let appleStatus = AppleIntelligenceAvailabilityService.shared.evaluateAvailability()
        let geminiStatus = GeminiAvailabilityService.shared.evaluateStatus()

        if !isOnline || geminiStatus == .networkOffline {
            return "OFFLINE"
        }

        switch geminiStatus {
        case .quotaLimited:
            return "GEMINI QUOTA LIMITED"
        case .notConfigured:
            if appleStatus.isUsable {
                return "APPLE LOCAL AI READY"
            } else {
                return "AI NOT CONFIGURED"
            }
        case .disabledByPolicy:
            if appleStatus.isUsable {
                return "APPLE LOCAL AI READY"
            } else {
                return "LOCAL RULE ENGINE"
            }
        case .networkOffline:
            return "OFFLINE"
        case .ready:
            if activeType == .online {
                return "GEMINI READY"
            } else if appleStatus.isUsable {
                return "HYBRID AI"
            } else {
                return "GEMINI READY"
            }
        }
    }

    private var statusBadgeStyle: StatusBadgeStyle {
        switch currentStatusKey {
        case "GEMINI READY", "HYBRID AI":
            return .indigo
        case "APPLE LOCAL AI READY":
            return .emerald
        case "LOCAL RULE ENGINE":
            return .neutral
        case "GEMINI QUOTA LIMITED":
            return .amber
        case "OFFLINE":
            return .neutral
        case "AI NOT CONFIGURED", "APPLE AI UNAVAILABLE":
            return .crimson
        default:
            return .neutral
        }
    }

    private var explanatoryText: String {
        switch currentStatusKey {
        case "GEMINI READY":
            return "Cloud AI active via Gemini Developer API (Free Tier). Complex academic reasoning enabled."
        case "HYBRID AI":
            return "Hybrid mode active. Balances Apple on-device neural processing with Gemini cloud intelligence."
        case "APPLE LOCAL AI READY":
            return "Apple on-device neural Foundation Models active. 100% private, zero network requests."
        case "LOCAL RULE ENGINE":
            return "Deterministic local academic rules active. Resilient, offline, zero network requests."
        case "GEMINI QUOTA LIMITED":
            return "Gemini free rate limit reached (429). Automatically operating via Local AI until reset."
        case "OFFLINE":
            return "Device is offline. All courses, notes, recordings, and local reasoning remain 100% functional."
        case "AI NOT CONFIGURED":
            return "Cloud AI is not configured (GoogleService-Info.plist missing). Running fully on local academic intelligence."
        case "APPLE AI UNAVAILABLE":
            return "Apple Foundation Models are unavailable on this device or OS. Operating safely via deterministic local rules."
        default:
            return "Local rules active. AcademicOS is running safely offline."
        }
    }

    public var body: some View {
        Button(action: { showingDetailsSheet = true }) {
            AcademicCard(
                cornerRadius: CornerRadius.large,
                padding: Spacing.medium,
                borderColor: statusBorderColor,
                backgroundColor: Color(uiColor: .secondarySystemBackground)
            ) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: activeType == .online ? "network" : "cpu")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(activeType == .online ? Color.academicPrimary : Color.academicEmerald)

                            Text("INTELLIGENT AI ROUTER")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Color.textPrimary)
                        }

                        Spacer()

                        StatusBadge(currentStatusKey, style: statusBadgeStyle)
                    }

                    Text(explanatoryText)
                        .font(.commandSubheadline)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.large) {
                        HStack(spacing: Spacing.xxSmall) {
                            Circle()
                                .fill(isOnline ? Color.academicEmerald : Color.academicAmber)
                                .frame(width: 6, height: 6)
                            Text(isOnline ? "Network Live" : "Offline Resilient")
                                .font(.commandCaption)
                                .foregroundColor(Color.textTertiary)
                        }

                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 10))
                            Text("Zero Data Leakage Guarantee")
                                .font(.commandCaption)
                                .foregroundColor(Color.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(Color.textTertiary)
                    }
                    .padding(.top, Spacing.xxSmall)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetailsSheet) {
            AIStatusDetailsSheet(statusKey: currentStatusKey, explanation: explanatoryText)
        }
    }

    private var statusBorderColor: Color {
        switch statusBadgeStyle {
        case .indigo: return Color.academicPrimary.opacity(0.4)
        case .emerald: return Color.academicEmerald.opacity(0.4)
        case .amber: return Color.academicAmber.opacity(0.4)
        case .crimson: return Color.academicCrimson.opacity(0.4)
        default: return Color.separatorPrimary
        }
    }
}

private struct AIStatusDetailsSheet: View {
    let statusKey: String
    let explanation: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(statusKey)
                    .font(.title2.bold())
                    .foregroundColor(Color.textPrimary)

                Text(explanation)
                    .font(.body)
                    .foregroundColor(Color.textSecondary)

                Divider()

                Text("Privacy & Free Tier Guarantees:")
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Zero recurring cloud cost guarantee (Developer API Free Tier).", systemImage: "creditcard.trianglebadge.exclamationmark")
                    Label("Passwords, LMS tokens, and Keychain secrets never leave device.", systemImage: "lock.fill")
                    Label("Offline audio recordings and SQLite remain 100% available.", systemImage: "internaldrive.fill")
                }
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)

                Spacer()
            }
            .padding()
            .navigationTitle("AI Engine Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
