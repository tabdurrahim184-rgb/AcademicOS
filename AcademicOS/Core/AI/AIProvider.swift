import Foundation

/// Type of AI compute provider.
public enum AIProviderType: String, Codable, Sendable {
    case online = "Cloud AI (Gemini)"
    case local = "Local AI (On-Device)"
}

/// Request payload sent to an AI provider.
public struct AIRequest: Sendable {
    public let prompt: String
    public let systemInstruction: String?
    public let contextData: [String: String]
    public let temperature: Double
    public let taskId: UUID?
    public let taskType: String?
    public let courseId: UUID?
    public let requiresStructuredOutput: Bool

    public init(
        prompt: String,
        systemInstruction: String? = nil,
        contextData: [String: String] = [:],
        temperature: Double = 0.7,
        taskId: UUID? = nil,
        taskType: String? = nil,
        courseId: UUID? = nil,
        requiresStructuredOutput: Bool = false
    ) {
        self.prompt = prompt
        self.systemInstruction = systemInstruction
        self.contextData = contextData
        self.temperature = temperature
        self.taskId = taskId
        self.taskType = taskType
        self.courseId = courseId
        self.requiresStructuredOutput = requiresStructuredOutput
    }
}

/// Structured response returned by an AI provider.
public struct AIResponse: Sendable {
    public let content: String
    public let providerType: AIProviderType
    public let modelIdentifier: String
    public let latencyMs: Int
    public let confidenceScore: Double
    public let isFallback: Bool

    public init(
        content: String,
        providerType: AIProviderType,
        modelIdentifier: String,
        latencyMs: Int,
        confidenceScore: Double = 0.98,
        isFallback: Bool = false
    ) {
        self.content = content
        self.providerType = providerType
        self.modelIdentifier = modelIdentifier
        self.latencyMs = latencyMs
        self.confidenceScore = confidenceScore
        self.isFallback = isFallback
    }
}

/// Base contract for any AI model execution engine.
public protocol AIProvider: AnyObject, Sendable {
    var providerType: AIProviderType { get }
    var modelIdentifier: String { get }
    var isAvailable: Bool { get }

    func generateResponse(for request: AIRequest) async throws -> AIResponse
}
