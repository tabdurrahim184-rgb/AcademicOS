import SwiftUI

/// Developer and diagnostics view for Near East University portal connectors.
/// Evaluates live subsystem health, validates DOM selectors, captures sanitized structure,
/// and exports diagnostic telemetry with zero credentials.
public struct NEUConnectorDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var coordinator = NEULivePortalCoordinator.shared

    @State private var isCapturing: Bool = false
    @State private var capturedFeedback: String?
    @State private var exportedJSON: String?
    @State private var showExportSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Profile Version Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SELECTOR PROFILE VERSION: \(coordinator.currentSelectorProfile.profileVersion)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("Near East University Connectors")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Spacer()
                        profileStatusBadge(coordinator.currentSelectorProfile.status)
                    }
                    .padding(Spacing.medium)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, Spacing.medium)

                    // DEBİM Subsystem Checklist
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("DEBİM MOODLE LMS SUBSYSTEMS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, Spacing.medium)

                        VStack(spacing: 6) {
                            diagnosticRow(title: "Google SAML Login Route", result: coordinator.latestDiagnostics.debimLogin)
                            diagnosticRow(title: "Moodle Dashboard (/my)", result: coordinator.latestDiagnostics.debimDashboard)
                            diagnosticRow(title: "Enrolled Course Discovery", result: coordinator.latestDiagnostics.debimCourses)
                            diagnosticRow(title: "Course Material Detection", result: coordinator.latestDiagnostics.debimMaterials)
                            diagnosticRow(title: "Assignment Parser", result: coordinator.latestDiagnostics.debimAssignments)
                            diagnosticRow(title: "Announcement Feed", result: coordinator.latestDiagnostics.debimAnnouncements)
                        }
                        .padding(Spacing.medium)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, Spacing.medium)
                    }

                    // Student Portal Subsystem Checklist
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("STUDENT PORTAL (OBS) SUBSYSTEMS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                            .padding(.horizontal, Spacing.medium)

                        VStack(spacing: 6) {
                            diagnosticRow(title: "Direct HTTPS Login (/Login/Login)", result: coordinator.latestDiagnostics.portalLogin)
                            diagnosticRow(title: "Genius Student Navigation", result: coordinator.latestDiagnostics.portalNavigation)
                            diagnosticRow(title: "Transcript Route (/StudentCourse/Transcript)", result: coordinator.latestDiagnostics.portalTranscript)
                            diagnosticRow(title: "Grades Extraction", result: coordinator.latestDiagnostics.portalGrades)
                            diagnosticRow(title: "Exam Schedule Parser", result: coordinator.latestDiagnostics.portalExamData)
                        }
                        .padding(Spacing.medium)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, Spacing.medium)
                    }

                    // Live Selector Learning Table
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Text("LIVE SELECTOR LEARNING")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(coordinator.currentSelectorProfile.verifiedFields.count) Verified")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, Spacing.medium)

                        VStack(spacing: 6) {
                            ForEach(Array(coordinator.currentSelectorProfile.selectors.keys.sorted()), id: \.self) { field in
                                HStack {
                                    Text(field)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Spacer()
                                    if coordinator.currentSelectorProfile.verifiedFields.contains(field) {
                                        Text("FOUND")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .clipShape(Capsule())
                                    } else {
                                        Text("AWAITING TEST")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(Spacing.medium)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, Spacing.medium)
                    }

                    // Action Controls
                    VStack(spacing: Spacing.small) {
                        Button(action: {
                            Task {
                                isCapturing = true
                                let export = await coordinator.captureSanitizedStructure(for: "NEU Student Portal")
                                isCapturing = false
                                if export != nil {
                                    capturedFeedback = "Sanitized structure captured successfully. Selectors validated."
                                } else {
                                    capturedFeedback = "Active page not connected or WebKit runtime offline."
                                }
                            }
                        }) {
                            HStack {
                                if isCapturing {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.viewfinder")
                                }
                                Text("CAPTURE SANITIZED STRUCTURE")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.academicPrimary)
                            .cornerRadius(10)
                        }

                        if let fb = capturedFeedback {
                            Text(fb)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            generateDiagnosticsJSON()
                            showExportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("EXPORT DIAGNOSTICS (JSON)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(Color.academicPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.academicPrimary.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, Spacing.medium)
                }
                .padding(.vertical, Spacing.medium)
            }
            .navigationTitle("NEU Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let json = exportedJSON {
                    DiagnosticsExportPreview(jsonString: json)
                }
            }
        }
    }

    private func diagnosticRow(title: String, result: DiagnosticsEvaluationResult) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(resultColor(result))
                    .frame(width: 6, height: 6)
                Text(result.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(resultColor(result))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(resultColor(result).opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.vertical, 3)
    }

    private func resultColor(_ result: DiagnosticsEvaluationResult) -> Color {
        switch result {
        case .pass: return .green
        case .fail: return .red
        case .pending: return .orange
        }
    }

    private func profileStatusBadge(_ status: SelectorProfileStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: SelectorProfileStatus) -> Color {
        switch status {
        case .liveVerified: return .green
        case .awaitingLiveValidation, .implemented: return .orange
        case .needsReview: return .red
        }
    }

    private func generateDiagnosticsJSON() {
        let dict: [String: Any] = [
            "report": "NEU_CONNECTION_DIAGNOSTICS",
            "evaluatedAt": ISO8601DateFormatter().string(from: Date()),
            "selectorProfileVersion": coordinator.currentSelectorProfile.profileVersion,
            "status": coordinator.currentSelectorProfile.status.rawValue,
            "verifiedSelectors": coordinator.currentSelectorProfile.verifiedFields,
            "unverifiedSelectors": coordinator.currentSelectorProfile.unverifiedFields,
            "debimState": coordinator.debimSessionState.rawValue,
            "portalState": coordinator.portalSessionState.rawValue,
            "securityNotice": "ZERO CREDENTIALS, ZERO TOKENS, ZERO PII INCLUDED"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            self.exportedJSON = str
        }
    }
}

/// Preview sheet for exported diagnostic JSON.
struct DiagnosticsExportPreview: View {
    @Environment(\.dismiss) private var dismiss
    let jsonString: String

    var body: some View {
        NavigationView {
            ScrollView {
                Text(jsonString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("NEU_CONNECTION_DIAGNOSTICS.json")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
