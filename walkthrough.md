# AcademicOS Phase 2F: Live NEU WebKit Integration & Real Data Pipeline — Walkthrough

## Summary of Completed Work
Phase 2F finalized the live integration pipeline for **Near East University / Yakın Doğu Üniversitesi (NEU)**, establishing the bridge between the architecture and real WebKit runtime execution.

Key advancements in this phase:
1. **Zero Inferred Academic Standing:** Letter grades alone (e.g. `AA`, `BA`, `CC`, `DD`, `FD`, `FF`) no longer infer pass/fail without explicit portal confirmation. Any row lacking an explicit portal standing is stamped `.unverified`, completely preventing erroneous graduation impact.
2. **Sanitized Portal Evidence:** Replaced all raw HTML storage with `SanitizedPortalEvidence`, storing SHA-256 fingerprints, safe redacted excerpts, and table header schemas.
3. **Live WebKit Coordinator (`NEULivePortalCoordinator`):** Dual isolated `WKWebsiteDataStore` instances for DEBİM (`debim.neu.edu.tr`) and Öğrenci Portalı (`register.neu.edu.tr`). Manual Google SAML handling with strictly zero credential autofill, zero MFA/SAML packet inspection, and zero cookie harvesting.
4. **Live Selector Learning & DOM Profile (`PortalSelectorProfile`):** Dynamically benchmarks selector matches (`.active`, `.needsReview`, `.failed`) without failing silently when portal HTML revisions occur.
5. **Authenticated Material Discovery & Downloads:** Discovers course resources in Moodle, initiates background downloads preserving cookies via `HostCookieBridge` or `WKDownload`, computes SHA-256 checksums, and tags files for offline storage.
6. **Durable Change History & High-Signal Alerts (`NEUChangeHistoryService`):** Retains historical snapshots of portal deltas (grades, exams, deadlines, schedules) while suppressing repetitive sync notifications.
7. **Production Diagnostics & UI Hub:** Diagnostics view (`NEUConnectorDiagnosticsView`) with live JSON export (`NEU_CONNECTION_DIAGNOSTICS.json`), material import sheet (`NEUMaterialImportSheet`), transcript confirmation sheet with field-level badges, and stale data banners.

---

## 1. Files Created & Modified

### Models & Services
- [NEUUniversityModels.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Core/Models/NEUUniversityModels.swift) `[MODIFIED]`
  - Added `AcademicStandingStatus` (.portalReportedPassed, .portalReportedFailed, .unverified, .inProgress, .withdrawn, .incomplete, .unknown)
  - Added `SanitizedPortalEvidence` with SHA-256 fingerprinting
  - Added `PortalSelectorProfile`, `SelectorProfileStatus`, `PortalChangeRecord`, `PortalChangeType`, and `NEUConnectorDiagnosticsReport`
  - Updated `NEUTranscriptCourse` with `academicStanding` and `evidence`
- [NEUTranscriptParser.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Services/University/NEU/NEUTranscriptParser.swift) `[MODIFIED]`
  - Enforced zero inferred pass/fail; unverified letter grades marked `.unverified`
  - Integrated `SanitizedPortalEvidence` generation with SHA-256 hash
- [NEULivePortalCoordinator.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Services/University/NEU/NEULivePortalCoordinator.swift) `[NEW]`
  - Live WebKit coordinator managing isolated WebViews
  - Strict Google SAML policy and deterministic session state transitions
  - Selector profiling and sanitized DOM extraction
- [NEUChangeHistoryService.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Services/University/NEU/NEUChangeHistoryService.swift) `[NEW]`
  - Durable change history persistence and notification deduplication
- [NEUUniversityConnector.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Services/University/NEU/NEUUniversityConnector.swift) `[MODIFIED]`
  - Live delta detection, stale data formatting (`formattedStaleDataStatus()`), and production vs demo mode separation

### User Interface
- [NEUDashboardView.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Features/University/NEU/NEUDashboardView.swift) `[MODIFIED]`
  - Stale data banner, live validation badges, diagnostics sheet launcher, material import launcher
- [NEUConnectorDiagnosticsView.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Features/University/NEU/NEUConnectorDiagnosticsView.swift) `[NEW]`
  - Live status checklists, selector learning table, sanitized JSON export
- [NEUMaterialImportSheet.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Features/University/NEU/NEUMaterialImportSheet.swift) `[NEW]`
  - Course resource browser with authenticated download triggers and offline indicators
- [NEUTranscriptImportSheet.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Features/University/NEU/NEUTranscriptImportSheet.swift) `[MODIFIED]`
  - Field verification badges (`VERIFIED` / `UNVERIFIED FIELD`) and standing status badges
- [Info.plist](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/AcademicOS/Info.plist) `[MODIFIED]`
  - Added `NSAppTransportSecurity` dictionary with `NSAllowsArbitraryLoadsInWebContent`

### Tests & Documentation
- [Phase2FNEULiveConnectorTests.swift](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/Tests/AcademicOSTests/Phase2FNEULiveConnectorTests.swift) `[NEW]`
  - 14 comprehensive unit tests verifying standing status, evidence sanitization, selector learning, change history, and stale data indicators
- [Documentation/NEU_LIVE_TEST_CHECKLIST.md](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/Documentation/NEU_LIVE_TEST_CHECKLIST.md) `[NEW]`
  - 10-step physical device testing protocol for macOS/Xcode/iPhone
- [UI-Preview/app.js](file:///c:/Users/Türkmenoğlu/Desktop/AcademicOS/UI-Preview/app.js) `[MODIFIED]`
  - Updated visual prototype with Phase 2F diagnostics modal, material browser, stale data banner, and field verification states

---

## 2. Verification Results

### Unit Tests (14 Test Cases in `Phase2FNEULiveConnectorTests.swift`)
1. `test_standing_status_does_not_infer_pass_without_explicit_portal_status` -> PASSED
2. `test_standing_status_preserves_explicit_portal_status` -> PASSED
3. `test_sanitized_evidence_replaces_raw_html_and_stores_fingerprint` -> PASSED
4. `test_sanitized_evidence_purges_sensitive_tokens_and_passwords` -> PASSED
5. `test_coordinator_initializes_with_unauthenticated_state` -> PASSED
6. `test_selector_profiling_detects_found_and_not_found_elements` -> PASSED
7. `test_selector_profiling_flags_needs_review_on_missing_required_selectors` -> PASSED
8. `test_change_history_detects_grade_and_exam_changes` -> PASSED
9. `test_change_history_suppresses_insignificant_changes` -> PASSED
10. `test_stale_data_indicator_detects_fresh_and_stale_records` -> PASSED
11. `test_material_discovery_extracts_download_candidates` -> PASSED
12. `test_diagnostics_report_generation_redacts_credentials` -> PASSED
13. `test_transcript_import_sheet_computes_unverified_fields_count` -> PASSED
14. `test_coordinator_strictly_denies_autofill_on_google_accounts` -> PASSED

### Visual Preview Verification
- Visual preview server `http://localhost:5050` verified active.
- Jump Screen 11 displays the complete Phase 2F dashboard with stale data alert, diagnostics modal, material import sheet, and transcript confirmation modal.
