import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Actual runtime availability status of Apple Foundation Models on the current device.
public enum AppleIntelligenceStatus: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS
    case unavailable(String)

    public var isUsable: Bool {
        return self == .available
    }

    public var statusDescription: String {
        switch self {
        case .available:
            return "Apple Intelligence Foundation Models are ready for on-device reasoning."
        case .deviceNotEligible:
            return "This device is not eligible for Apple Foundation Models."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is disabled in iOS System Settings."
        case .modelNotReady:
            return "On-device Foundation Model assets are downloading or preparing."
        case .unsupportedOS:
            return "Foundation Models framework is not supported on this OS/SDK version."
        case .unavailable(let reason):
            return "Foundation Models unavailable: \(reason)"
        }
    }
}

/// Abstract provider to allow evaluating Foundation Models availability via system API or test mocks.
public protocol FoundationModelAvailabilityProvider: Sendable {
    func evaluateAvailability() -> AppleIntelligenceStatus
}

/// Default system availability evaluator calling Apple's official SystemLanguageModel API when available.
public struct DefaultFoundationModelAvailabilityProvider: FoundationModelAvailabilityProvider {
    public init() {}

    public func evaluateAvailability() -> AppleIntelligenceStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .deviceNotEligible
                case .appleIntelligenceNotEnabled:
                    return .appleIntelligenceNotEnabled
                case .modelNotReady:
                    return .modelNotReady
                default:
                    return .unavailable(String(describing: reason))
                }
            @unknown default:
                return .unavailable("Unknown availability status")
            }
        } else {
            return .unsupportedOS
        }
        #else
        // When the SDK does not include FoundationModels or compiling on older toolchains
        return .unsupportedOS
        #endif
    }
}

/// Service that safely inspects Apple Foundation Models availability without throwing unhandled exceptions.
public final class AppleIntelligenceAvailabilityService: Sendable {
    public static let shared = AppleIntelligenceAvailabilityService()

    private let provider: any FoundationModelAvailabilityProvider

    public init(provider: any FoundationModelAvailabilityProvider = DefaultFoundationModelAvailabilityProvider()) {
        self.provider = provider
    }

    /// Evaluates current Foundation Models readiness using Apple's official runtime API.
    public func evaluateAvailability() -> AppleIntelligenceStatus {
        return provider.evaluateAvailability()
    }
}
