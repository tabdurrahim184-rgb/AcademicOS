import SwiftUI

/// Dedicated dashboard for Near East University (Yakın Doğu Üniversitesi / NEU).
/// Displays live status for DEBİM Moodle LMS and Öğrenci Portalı (OBS),
/// stale data warnings, real academic sections (exams, assignments, materials, grades, announcements),
/// diagnostics launcher, and dual-sync controls.
public struct NEUDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var debimState: UniversityConnectionState = .disconnected
    @State private var portalState: UniversityConnectionState = .disconnected
    @State private var debimLastSync: Date?
    @State private var portalLastSync: Date?
    @State private var staleDataText: String = "Henüz senkronize edilmedi"

    @State private var isSyncing: Bool = false
    @State private var syncStatusMessage: String?
    @State private var showTranscriptSheet: Bool = false
    @State private var showDiagnosticsSheet: Bool = false
    @State private var showMaterialsSheet: Bool = false

    @State private var activeConflicts: [SourceConflict] = []
    @State private var reconciledCourses: [NEUReconciledCourse] = []
    @State private var transcriptSummary: NEUTranscriptSummary?
    @State private var recentChanges: [PortalChangeRecord] = []
    @State private var discoveredMaterials: [DiscoveredCourseMaterial] = []

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Header & University Identification
                headerSection

                // Stale Data Warning Banner
                staleDataBanner

                // Dual System Status Cards
                dualSystemStatusGrid

                // Master Sync Action Bar
                masterActionBar

                // Provenance Legend Pill Row
                provenanceLegend

                // Discrepancy & Conflicts Banner / List
                if !activeConflicts.isEmpty {
                    conflictsSection
                }

                // Recent Detected Portal Changes
                if !recentChanges.isEmpty {
                    recentChangesSection
                }

                // Transcript Overview & GPA Safety Card
                if let summary = transcriptSummary {
                    transcriptSummaryCard(summary)
                }

                // Reconciled Unified Course List
                reconciledCoursesSection
            }
            .padding(.vertical, Spacing.medium)
        }
        .navigationTitle("Near East University")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTranscriptSheet) {
            if let summary = transcriptSummary {
                NEUTranscriptImportSheet(summary: summary) {
                    // Confirmed transcript import
                }
            }
        }
        .sheet(isPresented: $showDiagnosticsSheet) {
            NEUConnectorDiagnosticsView()
        }
        .sheet(isPresented: $showMaterialsSheet) {
            NEUMaterialImportSheet(materials: discoveredMaterials)
        }
        .task {
            await refreshLocalState()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(Color.academicPrimary)
                    .font(.system(size: 16))

                Text("NEAR EAST UNIVERSITY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.academicPrimary)

                Spacer()

                Text("AWAITING LIVE VALIDATION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            Text("Yakın Doğu Üniversitesi Portalları")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text("DEBİM Moodle LMS ve Öğrenci Bilgi Sistemi (OBS) canlı WebKit entegrasyonu.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Stale Data Banner

    private var staleDataBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            Text(staleDataText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Dual System Status Grid

    private var dualSystemStatusGrid: some View {
        HStack(spacing: Spacing.medium) {
            // DEBİM Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.blue)
                    Text("DEBİM LMS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    statusPill(debimState)
                }

                Text("debim.neu.edu.tr")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Google SAML:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Manual Flow")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                }

                Button(action: {
                    NEULivePortalCoordinator.shared.openDebim()
                }) {
                    Text("OPEN DEBİM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            .padding(Spacing.medium)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            // Student Portal Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                        .foregroundColor(.purple)
                    Text("OBS PORTAL")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    statusPill(portalState)
                }

                Text("register.neu.edu.tr")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Engine:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Genius 2.0.0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Button(action: {
                    NEULivePortalCoordinator.shared.openStudentPortal()
                }) {
                    Text("OPEN PORTAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                }
            }
            .padding(Spacing.medium)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func statusPill(_ state: UniversityConnectionState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor(state))
                .frame(width: 6, height: 6)
            Text(state.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(stateColor(state))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(stateColor(state).opacity(0.12))
        .clipShape(Capsule())
    }

    private func stateColor(_ state: UniversityConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .syncInProgress: return .blue
        case .authExpired, .error: return .red
        case .connecting, .offlineCached: return .orange
        case .disconnected: return .secondary
        }
    }

    // MARK: - Master Action Bar

    private var masterActionBar: some View {
        VStack(spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                Button(action: {
                    Task { await runSyncAll() }
                }) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "SYNCING PORTALS..." : "SYNC ALL")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.academicPrimary)
                    .cornerRadius(10)
                }
                .disabled(isSyncing)

                Button(action: {
                    showDiagnosticsSheet = true
                }) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("DIAGNOSTICS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(Color.academicPrimary)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, 12)
                    .background(Color.academicPrimary.opacity(0.12))
                    .cornerRadius(10)
                }
            }

            HStack(spacing: Spacing.small) {
                Button(action: {
                    if transcriptSummary != nil {
                        showTranscriptSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.plaintext.fill")
                        Text("TRANSCRIPT")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }

                Button(action: {
                    showMaterialsSheet = true
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("MATERIALS")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }

            if let msg = syncStatusMessage {
                Text(msg)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Provenance Legend

    private var provenanceLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA SOURCE PROVENANCE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AcademicDataSourceBadge.allCases, id: \.self) { badge in
                        HStack(spacing: 4) {
                            Image(systemName: badge.systemIcon)
                            Text(badge.displayName)
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor(badge).opacity(0.15))
                        .foregroundColor(badgeColor(badge))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func badgeColor(_ badge: AcademicDataSourceBadge) -> Color {
        switch badge {
        case .debim: return .blue
        case .neuStudentPortal: return .purple
        case .manual: return .orange
        case .aiDerived: return .green
        }
    }

    // MARK: - Conflicts Section

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundColor(.orange)
                Text("DISCREPANCIES DETECTED (\(activeConflicts.count))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
            }

            ForEach(activeConflicts) { conflict in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(conflict.entityId)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(conflict.fieldName)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: Spacing.medium) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PORTAL VALUE:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                            Text(conflict.primaryValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("DEBİM VALUE:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                            Text(conflict.conflictingValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }

                    if conflict.resolvedValue == nil {
                        HStack(spacing: Spacing.small) {
                            Button("Keep Portal") {
                                Task {
                                    await NEUUniversityConnector.shared.resolveConflict(conflictId: conflict.id, resolvedValue: conflict.primaryValue)
                                    await refreshLocalState()
                                }
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(6)

                            Button("Keep DEBİM") {
                                Task {
                                    await NEUUniversityConnector.shared.resolveConflict(conflictId: conflict.id, resolvedValue: conflict.conflictingValue)
                                    await refreshLocalState()
                                }
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("Resolved: \(conflict.resolvedValue ?? "")")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding(Spacing.medium)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Recent Changes Section

    private var recentChangesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(Color.academicPrimary)
                Text("NEW UPDATES (\(recentChanges.count))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.academicPrimary)
            }
            .padding(.horizontal, Spacing.medium)

            ForEach(recentChanges.prefix(4)) { ch in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ch.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(ch.detectedAt.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(ch.newValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(Spacing.medium)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, Spacing.medium)
            }
        }
    }

    // MARK: - Transcript Summary Card

    private func transcriptSummaryCard(_ summary: NEUTranscriptSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRANSCRIPT SUMMARY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("PORTAL REPORTED GPA")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.totalCourses) Courses / \(summary.totalSemesters) Semesters")
                        .font(.system(size: 14, weight: .bold))
                    Text("Passed: \(summary.passedCount) | Failed: \(summary.failedCount) | Unconfirmed: \(summary.unconfirmedCount)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let gpa = summary.portalReportedGPA {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("UNVERIFIED GPA MAPPING: Official catalog weighting rules pending verification.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, Spacing.medium)
    }

    // MARK: - Reconciled Courses Section

    private var reconciledCoursesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("RECONCILED COURSES (\(reconciledCourses.count))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.medium)

            if reconciledCourses.isEmpty {
                Text("No courses reconciled yet. Tap 'SYNC ALL' or 'OPEN PORTAL' to begin.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, Spacing.medium)
            } else {
                ForEach(reconciledCourses) { course in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(course.canonicalCode)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            HStack(spacing: 4) {
                                ForEach(course.badges, id: \.self) { badge in
                                    Text(badge.displayName)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(badgeColor(badge).opacity(0.15))
                                        .foregroundColor(badgeColor(badge))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Text(course.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        HStack {
                            if let instructor = course.instructor {
                                Label(instructor, systemImage: "person.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(course.credits)) Credits")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(Spacing.medium)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, Spacing.medium)
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshLocalState() async {
        let connector = NEUUniversityConnector.shared
        self.debimState = await connector.debimState
        self.portalState = await connector.studentPortalState
        self.debimLastSync = await connector.debimLastSync
        self.portalLastSync = await connector.studentPortalLastSync
        self.activeConflicts = await connector.activeConflicts
        self.transcriptSummary = await connector.cachedTranscriptSummary
        self.recentChanges = await connector.recentChanges
        self.staleDataText = await connector.formattedStaleDataStatus()
        if let report = await connector.cachedReconciliationReport {
            self.reconciledCourses = report.reconciledCourses
        }
    }

    private func runSyncAll() async {
        isSyncing = true
        syncStatusMessage = "Syncing DEBİM and Student Portal..."

        let localCourses = (try? await container.courseRepository.getCourses()) ?? []
        let result = await NEUUniversityConnector.shared.syncAll(localCourses: localCourses)

        await refreshLocalState()
        isSyncing = false

        if result.isDebimSuccess && result.isPortalSuccess {
            syncStatusMessage = "Both portals synced. DEBİM: \(result.debimItemsChanged) changes, Portal: \(result.portalItemsChanged) changes."
        } else if result.isDebimSuccess {
            syncStatusMessage = "DEBİM synced. Student Portal: \(result.portalError ?? "Offline")"
        } else if result.isPortalSuccess {
            syncStatusMessage = "Student Portal synced. DEBİM: \(result.debimError ?? "Offline")"
        } else {
            syncStatusMessage = "Sync failed for both portals. Check connection."
        }
    }
}
