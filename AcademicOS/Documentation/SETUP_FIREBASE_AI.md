# Setting Up Firebase AI Logic (Gemini Developer API Free Tier) for AcademicOS

This document provides step-by-step instructions for connecting AcademicOS to Google Gemini via the official Firebase AI Logic SDK under the **Zero-Cost Developer API Free Tier**.

> [!NOTE]
> **No Secret Keys in Source Code:** AcademicOS does NOT store API keys in source control. Everything is managed via Firebase Console and Apple App Attest.

---

## 0. Toolchain & Platform Requirements

- **IDE:** Xcode 26.2+ (or current active Xcode toolchain)
- **Language:** Swift 6.0+ (with Strict Concurrency checking enabled)
- **Deployment Target:** 
  - Baseline Target: iOS 17.0+ (Full offline core, SQLite, Audio, Local Rule Engine)
  - Advanced On-Device Intelligence: iOS 18.1+ / macOS 15.1+ (for Apple Foundation Models `SystemLanguageModel` runtime)
- **Firebase Apple SDK Constraint:** `11.0.0` or higher (Firebase 11+ / 12+)

---

## 1. Firebase Project Setup

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Create a new Firebase project (e.g. `AcademicOS-Personal`) or select an existing one.
3. **Billing Tier:** Keep the project on the **Spark (Free) Plan**. Do **not** upgrade to Blaze unless you explicitly desire paid Vertex AI quotas.

---

## 2. Register AcademicOS iOS Application

1. In Project Settings, click **Add App** and select **iOS**.
2. Set the iOS Bundle ID to:
   ```
   com.academicos.app
   ```
3. Enter App Nickname: `AcademicOS`.
4. Download the generated `GoogleService-Info.plist`.
5. Drag and drop `GoogleService-Info.plist` into the `AcademicOS` target root in Xcode. Ensure **Copy items if needed** is checked.

---

## 3. Install Firebase Apple SDK via Swift Package Manager

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the official Firebase Apple SDK repository URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. Select the version rule: `Up to Next Major` from `11.0.0` or latest supported release.
4. Add the following package products to the `AcademicOS` target:
   - `FirebaseCore`
   - `FirebaseAILogic`
   - `FirebaseAppCheck`

---

## 4. Enable Firebase AI Logic in Firebase Console

Run the following initialization command in your terminal:
```bash
npx -y firebase-tools@latest init ailogic
```
- Select your Firebase project.
- Choose **Gemini Developer API**.
- This automatically activates the Gemini Developer API in the Google Cloud Console for your project without requiring manual Google Cloud IAM setup.

---

## 5. Configure Firebase App Check

To protect your free tier quota from abuse or unauthorized clients:

### A. Debug Mode (Development / Simulator)
- AcademicOS automatically activates `AppCheckDebugProviderFactory` under `#if DEBUG`.
- When launching in Xcode, inspect the console log for:
  ```
  [FirebaseAppCheck] Debug token: <DEBUG-TOKEN>
  ```
- Copy `<DEBUG-TOKEN>` and paste it into **Firebase Console > App Check > Apps > Manage Debug Tokens**.
- **Never commit debug tokens to git!**

### B. Release Mode (App Store / TestFlight)
- In production, AcademicOS uses Apple's native **App Attest** provider (`AppAttestProvider`), with automatic fallback to **DeviceCheck** on older devices.
- Register your App Store Team ID in the Firebase App Check console under **App Attest**.

---

## 6. Verification & Testing Procedures

### A. Real Gemini Provider Verification
1. Place your registered `GoogleService-Info.plist` in the `AcademicOS` target root.
2. Build and run in Xcode (Simulator or connected iPhone).
3. Navigate to **Course Detail > AI Chat**.
4. Submit an academic question (e.g., *"Explain the difference between Habitus and Field"*).
5. Verify:
   - Response arrives with a **GEMINI** badge.
   - AI Telemetry view increments **GEMINI CLOUD CALLS**.
   - No error banners appear.

### B. Local AI & Fallback Verification
1. Enable **Airplane Mode** or disconnect Wi-Fi on the test device.
2. Submit a question in Course AI Chat or request a Lecture Note analysis.
3. Verify:
   - The status banner updates to **OFFLINE**.
   - If Apple Foundation Models are enabled on device, badge reads **APPLE LOCAL AI**.
   - If Apple Intelligence is unavailable or device is older, badge reads **LOCAL RULE ENGINE**.
   - Zero network requests are made.
   - Stored SQLite notes, courses, and recordings remain 100% accessible.

### C. Zero-Cost Policy Enforcement
AcademicOS will **never** silently incur billing. If free quota (HTTP 429) is exhausted:
- The system catches `AIProviderError.quotaExceeded`.
- The status banner displays **GEMINI QUOTA LIMITED**.
- The app seamlessly switches to local on-device reasoning until the daily quota resets.
- Zero paid cloud services or credit cards are ever required.
