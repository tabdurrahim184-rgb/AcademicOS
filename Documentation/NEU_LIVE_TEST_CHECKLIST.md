# Near East University Live Portal Test Checklist
### AcademicOS — Real iPhone & Xcode Hardware Verification Protocol

This document establishes the physical on-device verification procedure for testing Near East University (*Yakın Doğu Üniversitesi / NEU*) live portal integration inside Apple WebKit runtimes.

---

## 0. Pre-Flight Security & Setup Checklist

- [ ] Ensure the device is connected to a secure network.
- [ ] Verify that Developer Diagnostics mode is enabled in AcademicOS Settings.
- [ ] Confirm no hardcoded student credentials exist in the build.
- [ ] Confirm that `accounts.google.com` is configured in manual-only mode (autofill disabled).

---

## 1. DEBİM Moodle LMS (`debim.neu.edu.tr`) Live Verification

1. **DEBİM Login Launch:**
   - [ ] Tap **OPEN DEBİM** from the NEU Dashboard.
   - [ ] Verify that `https://debim.neu.edu.tr/login/index.php` loads cleanly in the isolated WKWebView.
   - [ ] Verify that AcademicOS shows session status `AUTHENTICATING`.

2. **Google SAML / SSO Redirect:**
   - [ ] Tap the Google SSO button on the Moodle login page.
   - [ ] Confirm navigation to `accounts.google.com`.
   - [ ] **Crucial Check:** Confirm AcademicOS **does not** prompt to save or autofill credentials on Google.
   - [ ] Enter Google student credentials and complete 2-Step Verification manually.

3. **Return to DEBİM & Session Detection:**
   - [ ] After successful Google authentication, verify automatic redirect back to `debim.neu.edu.tr`.
   - [ ] Confirm session status switches to `AUTHENTICATED` without asking AI models.
   - [ ] Confirm the DEBİM dashboard (`/my/`) renders the enrolled courses block.

4. **Course & Material Discovery:**
   - [ ] Open a course (e.g. *CENG 311*).
   - [ ] In Diagnostics, tap **CAPTURE SANITIZED STRUCTURE**.
   - [ ] Verify detected material links (`.pdf`, `.pptx`, `.docx`).
   - [ ] Tap **MATERIALS IMPORT** -> test downloading a lecture slide via `WKDownload`.
   - [ ] Confirm the file is stored locally, its SHA-256 hash is computed, and it opens offline.

---

## 2. Öğrenci Portalı OBS (`register.neu.edu.tr`) Live Verification

1. **Öğrenci Portalı Login:**
   - [ ] Tap **OPEN PORTAL** from the NEU Dashboard.
   - [ ] Confirm navigation to `https://register.neu.edu.tr/Login/Login`.
   - [ ] Enter student number and password manually into the login form.
   - [ ] Complete any required CAPTCHA verification.

2. **Dashboard & Navigation:**
   - [ ] Verify transition to the main dashboard (`/Home/Index`).
   - [ ] Confirm Genius Student 2.0.0 sidebar menu is responsive.
   - [ ] Confirm session status updates to `AUTHENTICATED`.

3. **Transcript Extraction & Preview:**
   - [ ] Navigate to `/StudentCourse/Transcript`.
   - [ ] Tap **TRANSCRIPT** in the NEU Action Bar.
   - [ ] Confirm **Transcript Import Preview** sheet opens.
   - [ ] **Crucial Check:** Confirm letter grades are flagged with `AcademicStandingStatus.unverified` unless explicit "Geçti" / "Kaldı" text is parsed.
   - [ ] **Crucial Check:** Confirm banner displays `PORTAL IMPORT — UNVERIFIED GPA MAPPING`.
   - [ ] Verify `CGPA` matches the value on the official portal page.
   - [ ] Tap **CONFIRM IMPORT**.

---

## 3. Dual-Portal Synchronization (`SYNC ALL`)

1. **Execution:**
   - [ ] Tap **SYNC ALL** while both portals have active sessions.
   - [ ] Verify DEBİM sync and Student Portal sync execute in sequence.
   - [ ] Confirm feedback banner: `"Both portals synced. DEBİM: X changes, Portal: Y changes."`

2. **Course Reconciliation & Discrepancies:**
   - [ ] Verify that courses present in both systems (e.g., *CENG 311*) are unified under canonical codes.
   - [ ] Confirm both `[DEBİM]` and `[NEU STUDENT PORTAL]` badges are attached.
   - [ ] If title or credit discrepancies exist, verify that a `SourceConflict` card appears.
   - [ ] Test tapping **Keep Portal** or **Keep DEBİM** to resolve the conflict.

---

## 4. Resilience & Offline Verification

1. **Partial Sync Resilience:**
   - [ ] Log out of DEBİM while keeping Öğrenci Portalı active.
   - [ ] Tap **SYNC ALL**.
   - [ ] Verify that Student Portal succeeds and updates, while DEBİM reports `LOGIN REQUIRED` gracefully.

2. **Offline Reopen & Stale Data:**
   - [ ] Enable Airplane Mode on the iPhone.
   - [ ] Force quit AcademicOS and reopen.
   - [ ] Verify all previously synced courses, materials, and transcript records remain fully readable.
   - [ ] Confirm the stale data indicator displays `"LAST VERIFIED: <date>"` or `"Son senkronizasyon: X saat önce"`.
   - [ ] Confirm no crash occurs due to lack of network.

3. **Session Expiry & Re-Login:**
   - [ ] Wait for portal ASP.NET session timeout.
   - [ ] Attempt a sync.
   - [ ] Confirm AcademicOS detects `SESSION_EXPIRED` and prompts for re-login without corrupting existing local database records.
