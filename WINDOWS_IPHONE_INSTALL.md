# AcademicOS Windows-to-iPhone Sideload Installation Guide

This document provides complete instructions for installing **AcademicOS** onto a physical iPhone directly from a **Windows 10 or 11 PC** without owning a Mac.

---

> [!CAUTION]
> **Zero Credential Rule in Source Code:**
> Never commit your personal Apple ID, password, or two-factor authentication codes to the AcademicOS codebase, GitHub, or any public repository. Signing occurs entirely on your local Windows PC via AltServer or Sideloadly.

---

## Prerequisites & Architecture Overview

Because AcademicOS is compiled as an **unsigned IPA** (`AcademicOS-unsigned.ipa`) by the GitHub Actions macOS runner, it must be signed with your personal Apple ID before iOS will allow it to execute. Apple provides free 7-day personal developer provisioning profiles to every Apple ID.

### Required Software on Windows:
1. **Apple iTunes (Non-Microsoft Store Version):** Required for Apple Mobile Device Support drivers.
2. **Apple iCloud (Non-Microsoft Store Version):** Required for Apple ID authentication protocol.
3. **AltServer for Windows** (or **Sideloadly**).
4. A physical Lightning or USB-C cable to connect your iPhone.

---

## Step-by-Step Installation Protocol

### Step 1: Download `AcademicOS-unsigned.ipa` from GitHub Actions
1. Open your GitHub repository in your web browser.
2. Navigate to the **Actions** tab.
3. Click on the latest **AcademicOS iOS Remote Build** workflow run.
4. Scroll down to the **Artifacts** section at the bottom of the summary page.
5. Click **AcademicOS-unsigned-ipa** to download the zip archive.
6. Extract the zip file on your Windows computer to reveal `AcademicOS-unsigned.ipa`.

---

### Step 2: Install iTunes and iCloud for Windows (Crucial Drivers)
> [!IMPORTANT]
> Do **NOT** install iTunes or iCloud from the Microsoft Store! The Microsoft Store versions sandbox device files and prevent sideloading tools from communicating with the iPhone.

1. **Download official standalone iTunes for Windows (64-bit):**
   - Download link: [Direct Apple iTunes Installer (64-bit)](https://www.apple.com/itunes/download/win64)
   - Run the installer and complete the setup.
2. **Download official standalone iCloud for Windows:**
   - Download link: [Direct Apple iCloud Installer](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8109-AE433483226E/iCloudSetup.exe)
   - Install iCloud and restart your Windows PC if prompted.

---

### Step 3: Install AltServer on Windows
1. Download AltServer for Windows from the official website: [https://altstore.io/](https://altstore.io/)
2. Extract the downloaded `altinstaller.zip` and run `setup.exe`.
3. Launch **AltServer** from your Windows Start Menu. (It will minimize to the notification tray next to the Windows clock).

---

### Step 4: Connect iPhone via USB Cable
1. Connect your iPhone to your Windows PC using an official or MFi-certified USB cable.
2. Unlock your iPhone screen.

---

### Step 5: Trust the Windows Computer
1. When prompted on your iPhone screen with *"Trust This Computer?"*, tap **Trust**.
2. Enter your iPhone device passcode to confirm.
3. Open iTunes on Windows and confirm that your iPhone appears in the top navigation bar.
4. Under the iPhone summary in iTunes, check **"Sync with this iPhone over Wi-Fi"** and click **Apply** (this enables wireless refreshing later).

---

### Step 6: Enable Developer Mode on Your iPhone (iOS 16, 17, 18+)
Apple requires Developer Mode to be enabled before sideloaded apps can run on iOS:
1. On your iPhone, open **Settings**.
2. Tap **Privacy & Security**.
3. Scroll to the very bottom and tap **Developer Mode**.
4. Toggle **Developer Mode** to **ON**.
5. Tap **Restart** when prompted.
6. After your iPhone reboots and you unlock it, tap **Turn On** on the confirmation dialog and enter your passcode.

---

### Step 7: Sideload `AcademicOS-unsigned.ipa` Using AltServer
1. On your Windows PC, locate the **AltServer** icon in the system notification tray (bottom-right taskbar).
2. Hold down the **Shift** key on your Windows keyboard and **Left-Click** the AltServer icon.
3. A menu will appear with the option: **"Sideload .ipa..."**
4. Select your connected iPhone from the sub-menu.
5. In the file picker dialog, choose the **`AcademicOS-unsigned.ipa`** file downloaded in Step 1.
6. AltServer will prompt you for your Apple ID credentials:
   - **Apple ID:** (Your personal Apple ID email)
   - **Password:** (Your Apple ID password or an App-Specific password)
   *(AltServer connects directly to Apple's provisioning server over HTTPS to generate a free 7-day personal certificate. Credentials are never saved or sent to third parties).*
7. Wait 60–90 seconds while AltServer codesigns the app and installs it onto your iPhone.

---

### Alternative Method: Using Sideloadly for Windows
If you prefer a standalone drag-and-drop tool:
1. Download **Sideloadly** for Windows from [https://sideloadly.io/](https://sideloadly.io/).
2. Open Sideloadly.
3. Drag and drop `AcademicOS-unsigned.ipa` onto the large IPA icon.
4. Enter your Apple ID email.
5. Click **Start**. Sideloadly handles signing and pushes the app directly to your iPhone.

---

### Step 8: Trust Your Personal Developer Profile on iPhone
Before launching AcademicOS for the first time:
1. On your iPhone, go to **Settings > General > VPN & Device Management**.
2. Under **Developer App**, tap your Apple ID email address.
3. Tap **Trust "[Your Apple ID]"**.
4. Confirm by tapping **Trust**.

---

### Step 9: Launch AcademicOS
1. Locate the **AcademicOS** app icon on your iPhone home screen.
2. Tap to launch.
3. AcademicOS will launch in high-performance dark mode command center style.
4. Grant runtime permissions when prompted:
   - **Microphone:** For recording university lectures.
   - **Speech Recognition:** For on-device transcript generation.
   - **Face ID:** For securing your academic records and grades.
   - **Notifications:** For high-signal grade and exam notifications.

---

## Understanding Apple's Free Provisioning Lifespan

### 1. The 7-Day Expiration Rule
- Apple’s free developer program grants **7 days** of execution for apps signed with a personal Apple ID.
- After 7 days, iOS will display *"AcademicOS is No Longer Available"* until refreshed.
- **Your data is NOT lost:** The local SQLite database, lecture audio recordings, course notes, and university credentials stored in the sandboxed container are completely preserved when refreshing.

### 2. How to Refresh (Under 30 Seconds)
- **Wireless Refresh:** As long as AltServer is running on your Windows PC and your iPhone is connected to the same Wi-Fi network, AltStore can refresh AcademicOS automatically in the background.
- **Manual Cable Refresh:** Simply reconnect your iPhone via USB, hold Shift, click AltServer > Sideload .ipa, and select the IPA (or click "Refresh" in AltStore). The app will update with a fresh 7-day validity window.

---

## Troubleshooting Common Windows Sideload Issues

| Issue / Error | Root Cause | Solution |
| :--- | :--- | :--- |
| **"Could not find Apple Mobile Device Support"** | Microsoft Store version of iTunes installed | Uninstall iTunes from Windows Apps. Install the direct standalone iTunes installer linked in Step 2. |
| **"Could not connect to AltServer"** | Windows Firewall blocking AltServer port | Open Windows Defender Firewall > Allow an app through firewall > Check both Private and Public for AltServer. |
| **"Developer Mode Required"** | iOS 16/17/18 Developer Mode disabled | Follow Step 6 to enable Developer Mode in Settings > Privacy & Security. |
| **"Maximum number of free apps reached"** | Apple limits free accounts to 3 active sideloaded apps | Remove an old sideloaded app from your iPhone or use a separate free Apple ID. |
| **"Untrusted Developer"** | Developer certificate not trusted in iOS Settings | Go to Settings > General > VPN & Device Management > Tap Apple ID > Tap Trust. |
