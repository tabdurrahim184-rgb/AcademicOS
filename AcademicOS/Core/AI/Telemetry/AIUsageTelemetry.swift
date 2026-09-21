import Foundation

/// On-device local-only AI telemetry metrics.
/// Zero data is transmitted to external analytics platforms.
public struct AIUsageMetrics: Codable, Sendable, Equatable {
    public var geminiRequestCount: Int = 0
    public var appleLocalRequestCount: Int = 0
    public var ruleEngineRequestCount: Int = 0
    public var fallbackCount: Int = 0
    public var quotaErrorCount: Int = 0
    public var totalLatencyMs: Int = 0
    public var lastProviderUsed: String = "None"
    public var lastUsedDate: Date?

    public var localRequestCount: Int {
        return appleLocalRequestCount + ruleEngineRequestCount
    }

    public var totalRequests: Int {
        return geminiRequestCount + localRequestCount
    }

    public var averageProcessingTimeMs: Int {
        guard totalRequests > 0 else { return 0 }
        return totalLatencyMs / totalRequests
    }

    public var averageLatencyMs: Int {
        return averageProcessingTimeMs
    }
}

/// Service that records AI usage purely in memory and local SQLite.
public final class AIUsageTelemetryService: @unchecked Sendable {
    public static let shared = AIUsageTelemetryService()

    private var metrics = AIUsageMetrics()
    private let lock = NSLock()

    private init() {}

    public func recordExecution(
        providerType: AIProviderType,
        modelIdentifier: String,
        latencyMs: Int,
        isFallback: Bool = false
    ) {
        lock.lock()
        defer { lock.unlock() }

        if providerType == .online {
            metrics.geminiRequestCount += 1
        } else {
            if modelIdentifier.contains("academicos-local-rules") || isFallback {
                metrics.ruleEngineRequestCount += 1
            } else {
                metrics.appleLocalRequestCount += 1
            }
        }

        if isFallback {
            metrics.fallbackCount += 1
        }

        metrics.totalLatencyMs += latencyMs
        metrics.lastProviderUsed = "\(providerType.rawValue) (\(modelIdentifier))"
        metrics.lastUsedDate = Date()
    }

    public func recordQuotaError() {
        lock.lock()
        defer { lock.unlock() }
        metrics.quotaErrorCount += 1
    }

    public func getMetrics() -> AIUsageMetrics {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }

    public func resetMetrics() {
        lock.lock()
        defer { lock.unlock() }
        metrics = AIUsageMetrics()
    }
}
