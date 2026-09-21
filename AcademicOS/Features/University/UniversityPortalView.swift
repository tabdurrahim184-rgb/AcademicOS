import SwiftUI

/// Main dashboard view for university portal integration, grades, announcements, and sync status.
/// Strictly READ-ONLY in Phase 2C (Import, Organize, Analyze).
public struct UniversityPortalView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var portalConfig: UniversityPortalConfig?
    @State private var announcements: [UniversityAnnouncement] = []
    @State private var grades: [UniversityGrade] = []
    @State private var unreadCount: Int = 0
    @State private var isSyncing: Bool = false
    @State private var syncStatusMessage: String?
    @State private var selectedSegment: PortalSegment = .announcements
    @State private var calculatedGPA: GPAResult?
    @State private var selectedGPAWeighting: GPAWeightingPolicy = .localCourseCredits
    @State private var showDisconnectDialog: Bool = false
    @State private var showSetupWizard: Bool = false
    @State private var showInspectionMode: Bool = false
    @State private var isSessionExpired: Bool = false
    @State private var lastSyncTimestamp: Date? = nil

    public enum PortalSegment: String, CaseIterable, Identifiable {
        case announcements = "Announcements"
        case grades = "Grades & GPA"
        case inbox = "Inbox"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Read-Only Security Disclaimer Pill
                readOnlyBanner

                // Session Expired Banner (If session expired, show prominent prompt with LOGIN AGAIN)
                if isSessionExpired {
                    sessionExpiredBanner
                }

                // Stale-Data Indication
                if let lastSync = lastSyncTimestamp, Date().timeIntervalSince(lastSync) > 86400 {
                    staleDataBanner(lastSync: lastSync)
                }

                // Connection & Sync Hero Card
                connectionHeroCard

                // Quick Telemetry Metrics
                telemetryGrid

                // Near East University Dedicated Hub Link
                NavigationLink(destination: NEUDashboardView()) {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("NEAR EAST UNIVERSITY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple)
                                Text("ACTIVE MAPPING")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundColor(.purple)
                                    .clipShape(Capsule())
                            }
                            Text("DEBİM Moodle & Öğrenci Portalı")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.medium)
                    .background(Color.purple.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, Spacing.medium)

                // Action Bar: Add University & Inspection Mode
                HStack(spacing: Spacing.small) {
                    Button(action: { showSetupWizard = true }) {
                        Label("Add Real University", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.medium)
                            .padding(.vertical, Spacing.small)
                            .background(Color.academicPrimary)
                            .clipShape(Capsule())
                    }

                    Button(action: { showInspectionMode = true }) {
                        Label("Inspect DOM", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.academicPrimary)
                            .padding(.horizontal, Spacing.small)
                            .padding(.vertical, Spacing.small)
                            .background(Color.academicPrimary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.medium)

                // Segmented Content Picker
                Picker("Section", selection: $selectedSegment) {
                    ForEach(PortalSegment.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.medium)

                // Segment Body
                switch selectedSegment {
                case .announcements:
                    announcementsSection
                case .grades:
                    gradesSection
                case .inbox:
                    UniversityInboxView()
                        .frame(minHeight: 400)
                }

                // Disconnect & Security Section
                disconnectSection
            }
            .padding(.bottom, Spacing.xxxLarge)
        }
        .sheet(isPresented: $showSetupWizard) {
            UniversitySetupWizardView { config, payload in
                portalConfig = UniversityPortalConfig(
                    portalType: config.portalType,
                    name: config.universityName,
                    baseURL: config.portalBaseURL.absoluteString
                )
                syncStatusMessage = "University '\(config.universityName)' configured."
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("University Portal")
        .confirmationDialog(
            "Disconnect University Portal",
            isPresented: $showDisconnectDialog,
            titleVisibility: .visible
        ) {
            Button("Clear Web Session & Cookies Only") {
                UniversityWebSessionManager.shared.clearWebSession(deleteKeychainCredentials: false)
                syncStatusMessage = "Web session cleared."
            }
            Button("Clear Web Session & Delete Keychain Password", role: .destructive) {
                UniversityWebSessionManager.shared.clearWebSession(deleteKeychainCredentials: true)
                syncStatusMessage = "Session and credentials wiped."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to clear only the active WebKit session cookies or also permanently remove your saved Keychain password.")
        }
        .task {
            await loadPortalData()
        }
        .refreshable {
            await triggerManualSync()
        }
    }

    // MARK: - Read-Only Banner

    private var readOnlyBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 11))
                .foregroundColor(Color.academicPrimary)

            Text("PHASE 2D READ-ONLY IMPORT & RECONCILIATION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.textSecondary)

            Spacer()

            Text("ZERO MUTATION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.academicPrimary.opacity(0.12))
                .foregroundColor(Color.academicPrimary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.xSmall)
    }

    // MARK: - Session Expired Banner

    private var sessionExpiredBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("University session expired.")
                    .font(.system(size: 12, weight: .bold))
                Text("Giriş süresi doldu. Şifreniz asla AI'a sorulmaz; güvenli tarayıcı ile tekrar giriş yapın.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("LOGIN AGAIN") {
                showSetupWizard = true
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .clipShape(Capsule())
        }
        .padding(Spacing.medium)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Stale Data Banner

    private func staleDataBanner(lastSync: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
            let daysAgo = max(1, Calendar.current.dateComponents([.day], from: lastSync, to: Date()).day ?? 1)
            Text("Last synchronized \(daysAgo) days ago. Showing offline cached records.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Hero Card

    private var connectionHeroCard: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.statusSuccess)
                            .frame(width: 8, height: 8)
                        Text("CONNECTED")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Color.statusSuccess)
                    }

                    Spacer()

                    if let syncDate = portalConfig?.lastSyncAt {
                        Text("Last Sync: \(formatSyncDate(syncDate))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.textSecondary)
                    }
                }

                Text(portalConfig?.name ?? "Demo University (UZEM / OBS) [DEMO DATA]")
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text(portalConfig?.baseURL ?? "https://uzem.university.edu.tr")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.textSecondary)

                Divider()

                HStack {
                    Button(action: {
                        Task { await triggerManualSync() }
                    }) {
                        HStack(spacing: Spacing.xSmall) {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Reconciling...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("SYNC NOW")
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.small)
                        .background(Color.academicPrimary)
                        .clipShape(Capsule())
                    }
                    .disabled(isSyncing)

                    Spacer()

                    if let msg = syncStatusMessage {
                        Text(msg)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.statusSuccess)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Telemetry Grid

    private var telemetryGrid: some View {
        HStack(spacing: Spacing.small) {
            miniStat(title: "ANNOUNCEMENTS", count: "\(announcements.count)", icon: "megaphone.fill", color: .academicPrimary)
            miniStat(title: "GRADES POSTED", count: "\(grades.count)", icon: "chart.bar.fill", color: .academicCyan)
            miniStat(title: "UNREAD INBOX", count: "\(unreadCount)", icon: "tray.fill", color: unreadCount > 0 ? .statusWarning : .textSecondary)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func miniStat(title: String, count: String, icon: String, color: Color) -> some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.small,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(count)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Announcements Section

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ForEach(announcements) { ann in
                UniversityAnnouncementRow(announcement: ann)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Grades Section

    private var gradesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // GPA Weighting Selector
            HStack {
                Text("WEIGHTING BASIS:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textSecondary)

                Spacer()

                Button(action: {
                    selectedGPAWeighting = (selectedGPAWeighting == .localCourseCredits) ? .ectsCredits : .localCourseCredits
                    recalculateGPA()
                }) {
                    Text(selectedGPAWeighting.displayName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.academicPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.academicPrimary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Spacing.medium)

            if let result = calculatedGPA {
                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    backgroundColor: Color.academicPrimary.opacity(0.1)
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CALCULATED TERM GPA")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(Color.academicPrimary)

                                if let honor = result.honorStatus {
                                    Text(honor)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.textPrimary)
                                }
                            }

                            Spacer()

                            Text(String(format: "%.2f", result.gpa))
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(Color.academicPrimary)
                        }

                        HStack {
                            Text(result.verificationStatus.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textSecondary)

                            Spacer()

                            Text("Scale: 4.00")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.medium)
            }

            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(grades) { grade in
                    UniversityGradeCard(grade: grade)
                }
            }
            .padding(.horizontal, Spacing.medium)
        }
    }

    // MARK: - Disconnect Section

    private var disconnectSection: some View {
        VStack(spacing: Spacing.small) {
            Button(role: .destructive, action: {
                showDisconnectDialog = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disconnect University Session")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.statusCritical)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.medium)
                .background(Color.statusCritical.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .padding(.horizontal, Spacing.medium)
        }
    }

    // MARK: - Data Management

    private func loadPortalData() async {
        portalConfig = try? await container.universityRepository.fetchActivePortal()
        announcements = (try? await container.universityRepository.fetchAnnouncements(courseId: nil)) ?? []
        grades = (try? await container.universityRepository.fetchGrades(courseId: nil)) ?? []
        unreadCount = (try? await container.universityRepository.fetchUnreadInboxCount()) ?? 0
        recalculateGPA()
    }

    private func recalculateGPA() {
        let subjects = grades.map { g in
            GPASubjectItem(courseCode: g.courseCode, credits: 3, ects: 5, letterGrade: g.letterGrade, numericalScore: g.score)
        }
        calculatedGPA = container.gpaCalculator.calculateGPA(subjects: subjects, policy: selectedGPAWeighting)
    }

    private func triggerManualSync() async {
        isSyncing = true
        syncStatusMessage = nil
        do {
            let report = try await container.universitySyncEngine.performSync()
            syncStatusMessage = "Reconciled \(report.totalChangesCount) items in \(String(format: "%.1f", report.durationSeconds))s"
            await loadPortalData()
        } catch {
            syncStatusMessage = "Reconciliation failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    private func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
