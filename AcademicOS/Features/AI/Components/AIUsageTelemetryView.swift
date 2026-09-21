import SwiftUI

/// On-device privacy-preserving view showing local AI telemetry and performance metrics.
public struct AIUsageTelemetryView: View {
    @State private var metrics = AIUsageTelemetryService.shared.getMetrics()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // Privacy Guarantee Header
                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    borderColor: Color.academicEmerald.opacity(0.4),
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Color.academicEmerald)
                            Text("LOCAL-ONLY AI TELEMETRY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textPrimary)
                            Spacer()
                            StatusBadge("ON-DEVICE ONLY", style: .emerald)
                        }
                        Text("Metrics are stored strictly on this iPhone to monitor zero-cost quota and latency. Zero telemetry data is transmitted externally.")
                            .font(.commandCaption)
                            .foregroundColor(Color.textSecondary)
                    }
                }

                // Metric Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.medium) {
                    MetricCard(title: "GEMINI CLOUD CALLS", value: "\(metrics.geminiRequestCount)", icon: "cloud.fill")
                    MetricCard(title: "APPLE LOCAL AI", value: "\(metrics.appleLocalRequestCount)", icon: "apple.logo")
                    MetricCard(title: "RULE ENGINE CALLS", value: "\(metrics.ruleEngineRequestCount)", icon: "gearshape.2.fill")
                    MetricCard(title: "FALLBACKS TO LOCAL", value: "\(metrics.fallbackCount)", icon: "arrow.triangle.branch")
                    MetricCard(title: "QUOTA ERRORS (429)", value: "\(metrics.quotaErrorCount)", icon: "exclamationmark.octagon")
                    MetricCard(title: "TOTAL EXECUTIONS", value: "\(metrics.totalRequests)", icon: "chart.bar.fill")
                }

                // Average Latency & Last Engine Used
                AcademicCard(
                    cornerRadius: CornerRadius.medium,
                    padding: Spacing.medium,
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Text("AVERAGE PROCESSING TIME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textTertiary)
                            Spacer()
                            Text("\(metrics.averageProcessingTimeMs) ms")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.academicPrimary)
                        }

                        Divider()

                        HStack {
                            Text("LAST PROVIDER USED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textTertiary)
                            Spacer()
                            Text(metrics.lastProviderUsed)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.textPrimary)
                        }
                    }
                }

                Button(action: {
                    AIUsageTelemetryService.shared.resetMetrics()
                    metrics = AIUsageTelemetryService.shared.getMetrics()
                }) {
                    HStack {
                        Spacer()
                        Text("Reset Telemetry Counters")
                            .font(.commandSubheadline)
                            .foregroundColor(Color.academicCrimson)
                        Spacer()
                    }
                    .padding(Spacing.small)
                }
            }
            .padding(Spacing.medium)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("AI Telemetry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            metrics = AIUsageTelemetryService.shared.getMetrics()
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color.academicPrimary)
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textTertiary)
            }
        }
    }
}
