import SwiftUI

/// Profile view showing student overview, academic progress, GPA tracker, and system configurations.
public struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ProfileViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            studentRepo: AppContainer.shared.studentRepository,
            profileRepo: AppContainer.shared.profileRepository,
            gradRepo: AppContainer.shared.graduationRepository,
            queueManager: AppContainer.shared.queueManager,
            dataHealthService: AppContainer.shared.dataHealthService,
            appContainer: AppContainer.shared
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Student & GPA Overview
                if let profile = viewModel.profile, let gpa = viewModel.gpaRecord {
                    StudentOverviewHeader(profile: profile, gpa: gpa)
                }

                // Graduation Progress Card
                if let grad = viewModel.graduationProgress {
                    AcademicCard(
                        cornerRadius: CornerRadius.large,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Text("GRADUATION STATUS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.textSecondary)

                                Spacer()

                                Text(grad.countdownFormatted)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.academicCyan)
                            }

                            ProgressView(value: grad.progressPercentage, total: 100.0)
                                .tint(Color.academicCyan)

                            HStack {
                                Text("\(grad.completedCredits) / \(grad.totalCreditsRequired) ECTS")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)

                                Spacer()

                                Text("\(Int(grad.progressPercentage))% Completed")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textPrimary)
                            }
                        }
                    }
                }

                // Settings, AI config, Keychain Security, Data Management & Demo Controls
                SettingsListSection(
                    isBiometricLocked: $viewModel.isBiometricLocked,
                    aiModeSelection: $viewModel.aiModeSelection,
                    keepScreenAwake: $viewModel.keepScreenAwake,
                    recordingQualityHigh: $viewModel.recordingQualityHigh,
                    healthReport: viewModel.healthReport,
                    queuedJobsCount: viewModel.queuedSyncJobsCount,
                    onToggleBiometric: {
                        viewModel.toggleBiometricLock()
                    },
                    onSeedDemoData: {
                        Task { await viewModel.seedDemoData() }
                    },
                    onResetDatabase: {
                        Task { await viewModel.resetDatabase() }
                    }
                )
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.xxxLarge)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Profile & Settings")
        .task {
            await viewModel.loadProfileData()
        }
        .refreshable {
            await viewModel.loadProfileData()
        }
    }
}
