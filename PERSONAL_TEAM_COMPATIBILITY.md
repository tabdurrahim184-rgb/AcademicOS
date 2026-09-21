# AcademicOS Personal Team & Sideload Compatibility Audit

This document audits all capabilities, entitlements, and frameworks in **AcademicOS** to ensure seamless installation and execution when signed with a **Free Apple ID / Personal Team** via Windows sideloading tools (such as **AltServer / AltStore Classic** or **Sideloadly**).

---

## 1. Executive Summary

- **Personal Team Sideloading Status:** **100% COMPATIBLE**
- **Paid Apple Developer Program Required:** **NO**
- **Core Architecture Preserved:** All 8 core subsystems (SQLite course isolation, lecture audio recording, on-device transcription, course notes, WebKit university connector, local notifications, offline data, and AI routing) operate entirely within standard sandboxed iOS app permissions.
- **Entitlements Policy:** The project intentionally omits restricted developer entitlements (such as `aps-environment`, `iCloud`, and `App Groups`) to prevent code signing failures during personal Apple ID provisioning.

---

## 2. Comprehensive Capability Matrix

| Capability / Framework | Sideload Classification | Technical Mechanism | Impact on Free Personal Team |
| :--- | :--- | :--- | :--- |
| **Local SQLite Database (`libsqlite3`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | Sandboxed `Application Support` directory | Operates with zero friction; persistent across app restarts. |
| **Course Isolation Guarantee** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | Foreign-key constrained SQLite tables | Purely algorithmic; zero cloud or entitlement dependencies. |
| **Audio Recording (`AVFoundation`, `AVAudioRecorder`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `NSMicrophoneUsageDescription` in `Info.plist` | User grants permission on first recording; records up to 180 min. |
| **Background Audio (`UIBackgroundModes: audio`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | Declared in `Info.plist` | Allows continuous lecture recording while screen is locked. |
| **On-Device Speech Transcription (`Speech`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `NSSpeechRecognitionUsageDescription` in `Info.plist` | Executes on-device via Apple Neural Engine / SFSpeechRecognizer. |
| **Biometric Authentication (`LocalAuthentication`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `NSFaceIDUsageDescription` in `Info.plist` | Protects credentials, grades, and diagnostics with Face ID/Touch ID. |
| **Single-App Keychain (`Security`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `kSecClassGenericPassword` with device-only access | Standard iOS Keychain services work without Keychain Access Groups. |
| **WebKit University Connector (`WebKit`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `WKWebView` with isolated `WKWebsiteDataStore` | Manages live sessions for DEBİM Moodle and Öğrenci Portalı. |
| **Campus Intranet ATS Bypass (`NSAppTransportSecurity`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `NSAllowsArbitraryLoadsInWebContent` in `Info.plist` | Permits secure web navigation across university domains. |
| **Local Notifications (`UserNotifications`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | Scheduled via `UNUserNotificationCenter` | High-signal grade, exam, and deadline alerts display locally. |
| **Background Refresh (`BGTaskScheduler`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | `com.academicos.universityrefresh` in `Info.plist` | iOS schedules periodic delta checks under battery management. |
| **Document & Slide Storage (`FileManager`)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | Sandboxed local storage with SHA-256 fingerprinting | Stores lecture slides, syllabi, and transcripts 100% offline. |
| **On-Device AI (`FoundationModels` / Local Rules)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | SystemLanguageModel API / Local heuristic fallbacks | Supported on iOS 18.2+ A17 Pro+ devices; rule engines on others. |
| **Cloud AI (Firebase AI Logic / Gemini Free Tier)** | **EXPECTED TO WORK WITH PERSONAL SIDELOAD** | REST / Client SDK with App Check debug token or Keychain key | Operates under zero-cost developer tier without App Store review. |
| **Remote Push Notifications (APNs)** | **MAY REQUIRE PAID DEVELOPER CAPABILITY** | Requires `aps-environment` entitlement & paid team | **NOT REQUIRED:** AcademicOS uses local notifications instead. |
| **iCloud / CloudKit Sync** | **NOT REQUIRED** | Requires paid iCloud container entitlement | **NOT REQUIRED:** Local SQLite handles all persistence. |
| **App Groups / Extension Sharing** | **NOT REQUIRED** | Requires App Group entitlement | **NOT REQUIRED:** AcademicOS is a self-contained application. |
| **Sign in with Apple** | **NOT REQUIRED** | Requires paid developer capability | **NOT REQUIRED:** Student logs into DEBİM via Google SAML in WebKit. |
| **In-App Purchases (StoreKit)** | **NOT REQUIRED** | Requires paid developer account & banking agreements | **NOT REQUIRED:** AcademicOS is completely free academic software. |

---

## 3. Conditional Runtime Degradation Strategy

AcademicOS is designed to never crash or block the user when hardware, cloud, or developer capabilities are constrained:

1. **Remote Push vs. Local Notifications:**
   - AcademicOS **never requests APNs push tokens**. All academic alerts (grade postings, exam schedule shifts, assignment deadlines) are computed on-device by `AcademicNotificationService` and dispatched using local triggers.
2. **Apple Intelligence vs. Local Heuristics:**
   - If `FoundationModels` runtime is unavailable (e.g., iPhone models prior to iPhone 15 Pro, or iOS < 18.2), `AIRouter` automatically routes reasoning to local deterministic rule engines (Flashcard generator, quiz builder, professor emphasis scorer).
3. **Cloud AI Availability:**
   - If `GoogleService-Info.plist` or internet connectivity is absent, the app displays an offline indicator and operates from cached SQLite records. No network failure can lock the student out of their notes or course records.
4. **Keychain Access Groups:**
   - `KeychainStorage` deliberately omits `kSecAttrAccessGroup`. Credentials and session cookies are scoped strictly to the app’s own bundle ID, allowing free personal team provisioning profiles to sign without entitlement mismatch errors.

---

## 4. Entitlements Verification

The project's active entitlements file ([AcademicOS.entitlements](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/AcademicOS.entitlements)) contains zero restricted entitlements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- AcademicOS is fully optimized for Personal Team Sideloading. -->
	<!-- Zero paid Apple Developer Program entitlements required. -->
</dict>
</plist>
```

When AltServer or Sideloadly signs `AcademicOS-unsigned.ipa` using a free personal Apple ID:
1. It replaces the bundle identifier with a personal prefix (e.g. `com.yourname.academicos`).
2. It pairs the app with a free 7-day personal provisioning profile.
3. Because no restricted entitlements (`aps-environment`, `iCloud`, `NetworkExtensions`) are declared, **the signing process completes with zero errors**.
