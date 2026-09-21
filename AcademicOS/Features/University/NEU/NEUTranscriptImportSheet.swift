import SwiftUI

/// Sheet allowing the student to inspect and confirm an imported Near East University transcript.
/// Emphasizes that GPA calculation is held in "UNVERIFIED GPA MAPPING" until official catalog weighting is verified,
/// and displays explicit field verification states.
public struct NEUTranscriptImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let summary: NEUTranscriptSummary
    public let onConfirm: () -> Void

    public init(summary: NEUTranscriptSummary, onConfirm: @escaping () -> Void) {
        self.summary = summary
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Safety & Verification Warning Banner
                    HStack(alignment: .top, spacing: Spacing.small) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("PORTAL IMPORT — UNVERIFIED GPA MAPPING")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)

                            Text("Resmi NEU katalog ağırlık kuralları doğrulanana kadar harf notlarından mezuniyet durumu türetilmez. Doğrulanmamış dersler mezuniyet uygunluğunu etkilemez.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(Spacing.medium)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, Spacing.medium)

                    // Summary Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.medium) {
                        statCard(title: "TOPLAM DÖNEM", value: "\(summary.totalSemesters)", icon: "calendar")
                        statCard(title: "TOPLAM DERS", value: "\(summary.totalCourses)", icon: "books.vertical.fill")
                        statCard(title: "GEÇİLEN (PORTAL)", value: "\(summary.passedCount)", icon: "checkmark.circle.fill", color: .green)
                        statCard(title: "DOĞRULANMAMIŞ", value: "\(summary.unconfirmedCount)", icon: "questionmark.circle.fill", color: .orange)
                    }
                    .padding(.horizontal, Spacing.medium)

                    // Field Verification Checklist Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALAN DOĞRULAMA DURUMU (FIELD STATUS)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            fieldBadge(name: "Ders Kodu", isVerified: true)
                            fieldBadge(name: "Ders Adı", isVerified: true)
                            fieldBadge(name: "Harf Notu", isVerified: true)
                            fieldBadge(name: "Geçti/Kaldı", isVerified: summary.unconfirmedCount == 0)
                        }
                    }
                    .padding(Spacing.medium)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, Spacing.medium)

                    // Portal Reported GPA Card
                    if let gpa = summary.portalReportedGPA {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PORTAL REPORTED GPA")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", gpa))
                                    .font(.system(size: 28, weight: .black, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("PROVENANCE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Image(systemName: AcademicDataSourceBadge.neuStudentPortal.systemIcon)
                                    Text(AcademicDataSourceBadge.neuStudentPortal.displayName)
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(Spacing.medium)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, Spacing.medium)
                    }

                    // Course Breakdown
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("İÇE AKTARILACAK DERSLER (\(summary.courses.count))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, Spacing.medium)

                        ForEach(summary.courses) { course in
                            HStack(alignment: .center, spacing: Spacing.medium) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(course.courseCode)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.primary)

                                        Text("\(course.academicYear) \(course.semester)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Text(course.courseName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text(course.grade)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.primary)

                                        Text(course.academicStanding.displayName)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(standingColor(course.academicStanding))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(standingColor(course.academicStanding).opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    Text("\(String(format: "%.1f", course.credits)) cr")
                                        .font(.system(size: 10, design: .monospaced))
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
                .padding(.vertical, Spacing.medium)
            }
            .navigationTitle("NEU Transcript Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Import") {
                        onConfirm()
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }

    private func fieldBadge(name: String, isVerified: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isVerified ? "checkmark.circle.fill" : "questionmark.circle.fill")
            Text(name)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isVerified ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
        .foregroundColor(isVerified ? .green : .orange)
        .clipShape(Capsule())
    }

    private func standingColor(_ standing: AcademicStandingStatus) -> Color {
        switch standing {
        case .portalReportedPassed: return .green
        case .portalReportedFailed: return .red
        case .unverified: return .orange
        case .withdrawn, .incomplete: return .purple
        case .inProgress: return .blue
        case .unknown: return .secondary
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color = .primary) -> some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding(Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
