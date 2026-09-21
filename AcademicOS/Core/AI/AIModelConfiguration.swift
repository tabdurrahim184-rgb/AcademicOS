import Foundation

/// Centralized model registry and tier constraint specification.
public struct AIModelConfiguration: Sendable, Equatable {
    /// Currently supported default model for Firebase AI Logic Gemini Developer API free tier.
    public static let defaultModelIdentifier: String = "gemini-3.8-flash"

    /// Supported models verified under the Gemini Developer API free tier.
    public static let supportedFreeTierModels: [String] = [
        "gemini-3.8-flash",
        "gemini-2.5-flash"
    ]

    /// Key for Firebase Remote Config dynamic model switching.
    public static let remoteConfigModelKey: String = "gemini_model_name"

    public let modelIdentifier: String
    public let isPaidTierAllowed: Bool

    public init(
        modelIdentifier: String = defaultModelIdentifier,
        isPaidTierAllowed: Bool = false
    ) {
        self.modelIdentifier = modelIdentifier
        self.isPaidTierAllowed = isPaidTierAllowed
    }

    /// Validates if a model name belongs to the safe free-tier list.
    public static func isPermittedFreeModel(_ model: String) -> Bool {
        return supportedFreeTierModels.contains(model)
    }
}
