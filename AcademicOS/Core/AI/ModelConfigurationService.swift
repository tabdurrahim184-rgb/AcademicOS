import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Service managing dynamic AI model selection without requiring architectural rewrites.
/// Prepares for Firebase Remote Config while defaulting safely to on-device zero-cost defaults.
public final class ModelConfigurationService: @unchecked Sendable {
    public static let shared = ModelConfigurationService()

    private var activeModel: String
    private let lock = NSLock()

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "academicos_gemini_model_name"),
           AIModelConfiguration.isPermittedFreeModel(saved) {
            self.activeModel = saved
        } else {
            self.activeModel = AIModelConfiguration.defaultModelIdentifier
        }
    }

    /// Retrieves the currently active cloud AI model identifier.
    public func getActiveModelName() -> String {
        lock.lock()
        defer { lock.unlock() }
        return activeModel
    }

    /// Updates the active model name, enforcing zero-cost free-tier validation.
    public func setModelName(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard AIModelConfiguration.isPermittedFreeModel(name) else {
            print("[AcademicOS] Rejected model '\(name)': must belong to approved free-tier models.")
            return false
        }

        self.activeModel = name
        UserDefaults.standard.set(name, forKey: "academicos_gemini_model_name")
        return true
    }

    /// Fetches model configuration from Firebase Remote Config if configured.
    /// Falls back to local default if Remote Config is absent or returns an invalid model.
    public func fetchRemoteConfigModelIfAvailable() async {
        #if canImport(FirebaseRemoteConfig)
        do {
            let remoteConfig = RemoteConfig.remoteConfig()
            try await remoteConfig.fetchAndActivate()
            let remoteModel = remoteConfig.configValue(forKey: AIModelConfiguration.remoteConfigModelKey).stringValue

            if let model = remoteModel, !model.isEmpty && AIModelConfiguration.isPermittedFreeModel(model) {
                _ = setModelName(model)
                print("[AcademicOS] Remote Config updated Gemini model to: \(model)")
            } else {
                print("[AcademicOS] Remote Config model value invalid or unapproved; retaining: \(getActiveModelName())")
            }
        } catch {
            print("[AcademicOS] Remote Config fetch failed: \(error.localizedDescription); using safe default.")
        }
        #else
        // Running without FirebaseRemoteConfig linked: retain safe local default
        #endif
    }
}
