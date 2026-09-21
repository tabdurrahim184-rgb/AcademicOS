# AcademicOS AI Model Configuration Guide

## Overview

AcademicOS uses **Firebase AI Logic** with the **Gemini Developer API** for cloud-based academic reasoning, alongside Apple Foundation Models and local deterministic engines for on-device reasoning.

To guarantee zero recurring costs and long-term maintainability, the application decouples model identification from business logic through `AIModelConfiguration` and `ModelConfigurationService`.

---

## 1. Default Production Model

### Preferred Default: `gemini-3.8-flash`

- **Identifier**: `gemini-3.8-flash`
- **Backend**: Firebase AI Logic (`FirebaseAILogic` Swift SDK)
- **Service Tier**: Gemini Developer API Free Tier (Zero Cloud Billing Required)
- **Token Allowance**: Supports multi-thousand token context windows suitable for university lectures and exam question synthesis.

> [!IMPORTANT]
> The undocumented alias `gemini-flash-latest` is strictly avoided in production code as its versioning is unstable across Firebase SDK updates.

---

## 2. Dynamic Model Architecture

Model identifiers are **never scattered or hardcoded** throughout UI views, agents, or repositories.

```
┌─────────────────────────────────────────────────────────────┐
│                 ModelConfigurationService                   │
│   - Reads from local UserDefaults persistence               │
│   - Enforces Free-Tier Safe Model Whitelist                 │
│   - Rejects Paid 'Pro' Models (Zero-Cost Guarantee)        │
│   - Firebase Remote Config Boundary Ready                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                Provides activeModelIdentifier
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    GeminiConfiguration                      │
│   - Initializes Firebase AI generativeModel                │
│   - Configures safety settings and system instructions      │
└─────────────────────────────────────────────────────────────┘
```

### Free-Tier Whitelist:
Only verified free-tier models are permitted:
1. `gemini-3.8-flash` (Default)
2. `gemini-2.5-flash` (Stable Fallback)

### Pro Model Rejection:
Any attempt to select a paid Pro model (e.g., `gemini-1.5-pro`, `gemini-ultra`) is rejected by `ModelConfigurationService.isFreeTierEligible(model:)` to ensure the student never incurs unexpected cloud fees.

---

## 3. Remote Config Integration Boundary

AcademicOS is engineered so that model names can be updated dynamically as Google updates the Gemini Developer API lineup, without requiring an App Store binary update.

In `ModelConfigurationService.swift`:
```swift
#if canImport(FirebaseRemoteConfig)
// Fetches remote parameter "academicos_gemini_model"
// Validates against free-tier whitelist before applying
#else
// Uses safe local default: gemini-3.8-flash
#endif
```

If Remote Config is not yet configured or device is offline:
- The service defaults safely to `gemini-3.8-flash`.
- The app operates with 100% functionality without network dependencies on Remote Config.

---

## 4. How to Change the Model Locally

In developer debug builds or app settings:
```swift
ModelConfigurationService.shared.setActiveModelName("gemini-2.5-flash")
```
If an invalid or paid model identifier is passed, the service logs a warning and retains the safe default (`gemini-3.8-flash`).
