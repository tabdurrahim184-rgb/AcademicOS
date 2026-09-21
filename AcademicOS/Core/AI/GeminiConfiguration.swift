import Foundation

/// Safe configuration parameters for the Google Gemini Developer API via Firebase AI Logic.
/// Explicitly enforces Zero-Cost Free Tier safeguards.
public struct GeminiConfiguration: Sendable, Equatable {
    /// Official model recommended for mobile apps using Firebase AI Logic.
    public static var defaultModelName: String {
        ModelConfigurationService.shared.getActiveModelName()
    }

    public let modelName: String
    public let isPaidTierAllowed: Bool
    public let maxOutputTokens: Int
    public let temperature: Double
    public let timeoutSeconds: TimeInterval
    public let systemInstruction: String

    public init(
        modelName: String = ModelConfigurationService.shared.getActiveModelName(),
        isPaidTierAllowed: Bool = false,
        maxOutputTokens: Int = 4096,
        temperature: Double = 0.4,
        timeoutSeconds: TimeInterval = 30.0,
        systemInstruction: String = "You are the AcademicOS Academic Intelligence assistant. Ground answers in verified academic context."
    ) {
        self.modelName = modelName
        self.isPaidTierAllowed = isPaidTierAllowed
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.systemInstruction = systemInstruction
    }

    /// Factory for the default zero-cost configuration.
    public static var zeroCostDefault: GeminiConfiguration {
        return GeminiConfiguration()
    }
}
