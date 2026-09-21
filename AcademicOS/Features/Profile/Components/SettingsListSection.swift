import SwiftUI

/// Settings section for AI provider selection, audio recording preferences, security, and local SQLite data management.
public struct SettingsListSection: View {
    @Binding public var isBiometricLocked: Bool
    @Binding public var aiModeSelection: String
    @Binding public var keepScreenAwake: Bool
    @Binding public var recordingQualityHigh: Bool
    public let healthReport: DataHealthReport?
    public let queuedJobsCount: Int
    public let onToggleBiometric: () -> Void
    public let onSeedDemoData: () -> Void
    public let onResetDatabase: () -> Void

    public init(
        isBiometricLocked: Binding<Bool>,
        aiModeSelection: Binding<String>,
        keepScreenAwake: Binding<Bool>,
        recordingQualityHigh: Binding<Bool>,
        healthReport: DataHealthReport? = nil,
        queuedJobsCount: Int = 0,
        onToggleBiometric: @escaping () -> Void,
        onSeedDemoData: @escaping () -> Void,
        onResetDatabase: @escaping () -> Void
    ) {
        self._isBiometricLocked = isBiometricLocked
        self._aiModeSelection = aiModeSelection
        self._keepScreenAwake = keepScreenAwake
        self._recordingQualityHigh = recordingQualityHigh
        self.healthReport = healthReport
        self.queuedJobsCount = queuedJobsCount
        self.onToggleBiometric = onToggleBiometric
        self.onSeedDemoData = onSeedDemoData
        self.onResetDatabase = onResetDatabase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // AI Mode Configuration
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("AI ENGINE CONFIGURATION")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Picker("AI Routing Mode", selection: $aiModeSelection) {
                            Text("Automatic (AIRouter)").tag("Automatic")
                            Text("Online Preferred").tag("Online Preferred")
                            Text("Offline Preferred").tag("Offline Preferred")
                        }
                        .pickerStyle(.segmented)

                        Text(aiModeSelection == "Automatic"
                             ? "Smart failover: uses Gemini Cloud when online and falls back to Apple Neural Engine when offline."
                             : (aiModeSelection == "Online Preferred" ? "Prioritizes cloud AI models whenever internet is available." : "Prioritizes on-device private compute without network calls."))
                            .font(.commandCaption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }

            // Audio & Recording Preferences
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("LECTURE RECORDING PREFERENCES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(spacing: Spacing.medium) {
                        Toggle("Keep Screen Awake in Recording", isOn: $keepScreenAwake)
                            .font(.commandHeadline)

                        Divider().background(Color.borderSubtle)

                        Toggle("High Fidelity Speech Encoding (64 kbps AAC)", isOn: $recordingQualityHigh)
                            .font(.commandHeadline)

                        Divider().background(Color.borderSubtle)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Background Recording Active")
                                    .font(.commandHeadline)
                                Text("Recording continues when screen is locked via AVAudioSession")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }
                            Spacer()
                            StatusBadge("ENABLED", style: .emerald)
                        }
                    }
                }
            }

            // Security & Credentials
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("SECURITY & KEYCHAIN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(spacing: Spacing.medium) {
                        HStack {
                            Image(systemName: "faceid")
                                .font(.system(size: 20))
                                .foregroundColor(Color.academicPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Biometric Lock (Face ID)")
                                    .font(.commandHeadline)
                                Text("Require biometric unlock for LMS credentials & grades")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $isBiometricLocked)
                                .labelsHidden()
                                .onChange(of: isBiometricLocked) {
                                    onToggleBiometric()
                                }
                        }

                        Divider().background(Color.borderSubtle)

                        settingRow(
                            icon: "key.fill",
                            title: "iOS Keychain Hardware Enclave",
                            subtitle: "Zero hardcoded credentials • Hardware-encrypted",
                            badge: "SECURED",
                            badgeStyle: .emerald
                        )
                    }
                }
            }

            // Data Safety & Local Storage
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("DATA SAFETY & SANDBOX STORAGE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(spacing: Spacing.medium) {
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(Color.academicCyan)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Local Storage Used")
                                    .font(.commandHeadline)
                                Text("Audio: \(healthReport?.audioStorageFormatted ?? "0 MB") • SQLite: \(healthReport?.databaseStorageFormatted ?? "0 KB")")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            Text(healthReport?.totalStorageFormatted ?? "Calculating...")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textPrimary)
                        }

                        Divider().background(Color.borderSubtle)

                        HStack {
                            Image(systemName: "shield.checkerboard")
                                .foregroundColor(Color.academicEmerald)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data Health Diagnostics")
                                    .font(.commandHeadline)
                                Text(healthReport?.isHealthy == true ? "Filesystem & SQLite in perfect sync" : "Storage discrepancies detected")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            StatusBadge(healthReport?.isHealthy == true ? "HEALTHY" : "CHECK", style: healthReport?.isHealthy == true ? .emerald : .amber)
                        }
                    }
                }
            }

            // Developer Demo Mode
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("DEVELOPER TOOLS & DEMO MODE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .tracking(1.0)

                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(spacing: Spacing.medium) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Load Sample University Data")
                                    .font(.commandHeadline)
                                Text("Populates 7 journalism courses, missions, and exam dates for preview")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            Button("Load Demo") {
                                onSeedDemoData()
                            }
                            .font(.commandSubheadline)
                            .foregroundColor(Color.academicPrimary)
                        }

                        Divider().background(Color.borderSubtle)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Local SQLite Database")
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.academicCrimson)
                                Text("Wipes local sandbox records and re-triggers onboarding")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            Button("Reset Data") {
                                onResetDatabase()
                            }
                            .font(.commandSubheadline)
                            .foregroundColor(Color.academicCrimson)
                        }
                    }
                }
            }
        }
    }

    private func settingRow(
        icon: String,
        title: String,
        subtitle: String,
        badge: String,
        badgeStyle: StatusBadge.Style
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.academicPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text(subtitle)
                    .font(.commandCaption)
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            StatusBadge(badge, style: badgeStyle)
        }
    }
}
