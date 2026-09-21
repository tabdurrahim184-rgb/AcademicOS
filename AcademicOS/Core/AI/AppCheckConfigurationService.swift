import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

/// Factory managing Firebase App Check providers for AcademicOS without exposing debug secrets.
public final class AppCheckConfigurationService: @unchecked Sendable {
    public static let shared = AppCheckConfigurationService()

    private var isConfigured: Bool = false
    private let lock = NSLock()

    private init() {}

    /// Initializes App Check before FirebaseApp.configure() is invoked.
    /// Safely handles missing configurations in offline or local testing environments.
    public func configureAppCheckIfAvailable() {
        lock.lock()
        defer { lock.unlock() }

        guard !isConfigured else { return }

        #if canImport(FirebaseAppCheck) && canImport(FirebaseCore)
        // Only configure if GoogleService-Info.plist is actually present in the bundle
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("[AcademicOS] GoogleService-Info.plist not found; App Check initialization bypassed safely.")
            return
        }

        #if DEBUG
        // In DEBUG, utilize the App Check Debug Provider.
        // The debug token must be supplied via launch argument or environment variable, never hardcoded in source.
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AcademicOS] Firebase App Check configured with Debug Provider Factory.")
        #else
        // In RELEASE, utilize Apple App Attest with DeviceCheck fallback
        let providerFactory = AcademicOSAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("[AcademicOS] Firebase App Check configured with Production App Attest Provider Factory.")
        #endif

        self.isConfigured = true
        #else
        print("[AcademicOS] FirebaseAppCheck framework not compiled; App Check bypassed.")
        #endif
    }
}

#if canImport(FirebaseAppCheck) && canImport(FirebaseCore)
/// Custom App Check provider factory configuring Apple App Attest with DeviceCheck fallback.
private final class AcademicOSAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
    }
}
#endif
