# SHIP THE REAL ATTENDGUARD APP — Thursday 19 Nov 2026

This package provides **two distinct, genuine builds**. Neither claims that a local simulation was recorded in Firebase.

| Workflow | Entry point | What it actually does | Requires Firebase? |
|---|---|---|---|
| `Build AttendGuard ESP32 hardware test APK` | `lib/main_hardware_test.dart` | **Real Android BLE scanning** of 0xFFFF/A7 packets; shows received 8-digit codes, RSSI, and last-seen time | No |
| `Build AttendGuard REAL attendance APK (Firebase)` | `lib/main.dart` | **Real** Firebase email/password sign-in, lookupSession, markPresent, live rounds listener, confirmRecheck | **Yes** |

**The hardware test app is not the final attendance app.** It is a genuine BLE receiver, NOT a fake attendance simulator. The real attendance app is the second workflow. The old `main_demo.dart` is a development-only legacy entrypoint and is not used by either workflow.

## Your task as the mobile developer

1. Upload this update to GitHub, confirm the BLE hardware-test APK builds and install it on a physical Android phone.
2. Get ESP32 team to broadcast the proper payload. Confirm the hardware-test app detects an actual number, e.g. `12345678`.
3. Get Firebase team to provide the **Android Firebase config** and deploy the callable functions and Firestore rules listed in `BEACON_AND_BACKEND_CONTRACT.md`.
4. Configure the four repo secrets, run the **REAL attendance** workflow, install that APK on the phone.
5. Log in as an enrolled test student. Start a real session from lecturer dashboard; tap Mark Present; verify the record on the dashboard. Then verify re-checks.

## Firebase setup (no server credentials in your public repo)

The Firebase team must register Android app **package name `com.example.attendguard`** to match this workflow's generated Flutter project, or update the package ID in both workflows to match their registered Android app.

Get Android client Firebase options from Firebase Console > Project settings > Your apps. Set these as GitHub **Actions repository secrets**:

- `FIREBASE_API_KEY` (Android Firebase client API key — not a service account password)
- `FIREBASE_APP_ID` (Android app ID, starts with `1:` and includes `:android:`)
- `FIREBASE_SENDER_ID` (Messaging sender / project number)
- `FIREBASE_PROJECT_ID` (Firebase project identifier)

You can do this in GitHub: repository > **Settings > Secrets and variables > Actions > New repository secret**. The Firebase project must have **Email/Password Auth enabled** and a test student account. The deployed Firebase Functions (`lookupSession`, `markPresent`, `confirmRecheck`) must use the **default `us-central1` functions region**, unless the mobile backend adapter is updated to point to their actual region.

The Android Firebase values are client configuration, not authority to read Firestore; Firebase Rules, Auth, and Cloud Functions provide security. Do not put Firebase Admin private keys, service-account JSON, `.env` files, or student passwords in GitHub.

## PowerShell commands

Open Windows PowerShell and run:

```powershell
cd "$HOME\Documents\attendguard-mobile"

# Download AttendGuard_Real_App_Update.zip into Downloads first.
Expand-Archive -Path "$HOME\Downloads\AttendGuard_Real_App_Update.zip" -DestinationPath . -Force

py scripts/check_public_repo.py

git add .github/workflows/demo-apk.yml .github/workflows/live-apk.yml

git add lib/main.dart lib/main_hardware_test.dart lib/screens/hardware_test_screen.dart

git add README.md SHIP_REAL_APP.md BEACON_AND_BACKEND_CONTRACT.md AUDIT_REPORT.md

git diff --cached --name-only

git commit -m "Ship real BLE scanner and Firebase attendance APK workflows"

git push origin main
```

On push, the ESP32 hardware test workflow runs. After it succeeds:

```powershell
# Download the latest SUCCESSFUL hardware-test build by reading the id first:
gh run list -R Tileesha6/attendguard-mobile -L 5
# Then supply the successful run ID (replace 1234567890):
gh run download 1234567890 -R Tileesha6/attendguard-mobile -n AttendGuard-ESP32-Hardware-Test-APK -D "$HOME\Downloads\AttendGuard-Hardware-Test"
```

Once Firebase secrets and functions are in place, trigger the real build:

```powershell
gh workflow run live-apk.yml -R Tileesha6/attendguard-mobile --ref main
gh run list -R Tileesha6/attendguard-mobile -L 5
# Use the successful REAL workflow run ID:
gh run download 1234567890 -R Tileesha6/attendguard-mobile -n AttendGuard-REAL-Attendance-APK -D "$HOME\Downloads\AttendGuard-Real-APK"
```

> Note: release APKs from separate GitHub runners can be signed differently by Flutter's default debug signing configuration. You may need to uninstall an older test build before installing a new APK. Uninstalling resets the locally generated install ID and may require an admin to reset Firebase device binding. Avoid reinstalling after binding a student account.

## Before you call it finished

- [ ] Hardware APK installs and starts on Android phone
- [ ] Bluetooth off -> Android enables it only after user approves
- [ ] ESP32 USB `CODE:12345678` results in real scan of `12345678`
- [ ] Firebase real APK installs and logs in using team-provided student credentials
- [ ] Enrolled student sees correct course/hall after hearing BLE code
- [ ] Pressing **Mark me present** writes to Firestore through `markPresent`
- [ ] Lecturer dashboard updates in real time
- [ ] Re-check confirmed with a fresh BLE advertisement
- [ ] No code exposed on live student screens and no service secrets committed

## Important limits

- **No Firebase project or server functions were supplied to this bundle**; real attendance cannot succeed until the backend team deploys them.
- Real Flutter APK compilation has **not** been completed in this environment; GitHub Actions must validate it.
- Current student's history tab is not wired to a reporting API yet; it is not required for the essential check-in demo.
- ESP32 code setting remains the lecturer dashboard's responsibility via USB; the student app has no admin code-update capability.
