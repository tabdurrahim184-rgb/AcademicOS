import Foundation

/// Protocol for cloud-based AI providers.
public protocol OnlineAIProvider: AIProvider {
    var apiKeyConfigured: Bool { get }
    func configureApiKey(_ key: String)
}

/// Cloud AI implementation targeting Google Gemini API.
/// In Phase 1, simulates execution without making paid external calls.
public final class GeminiOnlineAIProvider: OnlineAIProvider, @unchecked Sendable {
    public let providerType: AIProviderType = .online
    public let modelIdentifier: String
    private let lock = NSLock()
    private var internalApiKey: String?

    public var apiKeyConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return internalApiKey != nil && !(internalApiKey?.isEmpty ?? true)
    }

    public var isAvailable: Bool {
        // In Phase 1, available for testing router logic
        return true
    }

    public init(modelIdentifier: String = "gemini-1.5-pro-academic") {
        self.modelIdentifier = modelIdentifier
    }

    public func configureApiKey(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        self.internalApiKey = key
    }

    public func generateResponse(for request: AIRequest) async throws -> AIResponse {
        let startTime = Date()
        // Simulate remote network latency (150ms)
        try await Task.sleep(nanoseconds: 150_000_000)

        let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
        let simulatedContent = """
        [Cloud Gemini Response (\(modelIdentifier))]
        Analysis for prompt: "\(request.prompt)"
        Context: \(request.contextData.count) course reference items analyzed.
        Status: High-precision academic reasoning verified.
        """

        return AIResponse(
            content: simulatedContent,
            providerType: .online,
            modelIdentifier: modelIdentifier,
            latencyMs: elapsed,
            confidenceScore: 0.99
        )
    }
}
