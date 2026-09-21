# AcademicOS Xcode & Toolchain Requirements

This document specifies the official developer toolchain requirements for building and compiling AcademicOS.

---

## Toolchain Specification

- **Recommended IDE:** Xcode 16.2 or later
- **Minimum macOS Version:** macOS Sequoia 15.2 or later
- **Swift Language Version:** Swift 6.0 (Strict Concurrency Checking enabled)
- **Deployment Target:** iOS 17.0+ (iOS 18+ / iOS 26+ for native Foundation Models runtime features)

---

## Rationale for Xcode 16.2+

1. **Firebase AI Logic Compatibility:**
   The `FirebaseAILogic` Swift SDK (Firebase 11+) utilizes modern Swift 6 macros and structured concurrency primitives (`@Sendable`, actor isolation) that require the updated Swift 6.0.3+ compiler toolchain bundled with Xcode 16.2+.
   *(Note: The previous documentation note recommending general "Xcode 16+" has been updated to explicitly require Xcode 16.2+).*

2. **Apple Foundation Models (`FoundationModels.framework`):**
   Runtime API calls (`SystemLanguageModel.default.availability` and `LanguageModelSession`) are conditionally imported under `#if canImport(FoundationModels)`. Compiling against modern SDKs requires the latest system headers provided in macOS 15.2+ / Xcode 16.2+.

3. **Graceful Degradation for Older Toolchains:**
   If compiled on environments without `FirebaseAILogic` or `FoundationModels`, the codebase employs `#if canImport(...)` checks to build cleanly, falling back to local deterministic rule engines so core course management, lecture recording, and SQLite operations never fail.
