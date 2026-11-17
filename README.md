# AttendGuard — Flutter Android student app (48-hour hackathon)

Public-repository-ready **source files** for an Android classroom attendance app
built around an ESP32 BLE beacon and Firebase. The repository deliberately contains
**no credentials, `.env` files, signing keys, or live student data**.

## What works / what's incomplete

| Feature | Local demo APK | Firebase live APK |
|---|---|---|
| App UI, tabs, permission handling | Included | Included |
| Scan real ESP32 manufacturer BLE advertisements | Included; uses simulated backend | Included |
| Simulate beacon without hardware | Included and visibly marked as local only | Not exposed |
| Login and verified check-in on server | **Not possible** | Requires backend integration |
| Re-check prompt | Simulated locally | Uses Firestore listener and callable function |
| Attendance history and percentages | Placeholder screen | Not implemented yet |

The local demo app can detect a real beacon and display a mock course, but it **does
not record attendance**. Your teammates must deploy Firebase Auth, Cloud Functions,
Firestore security rules and courses to enable the live path.

## Get an APK from GitHub (no Flutter on your PC)

1. Follow **UPLOAD_FROM_WINDOWS.md** to upload these files to a public repo.
2. Open the GitHub **Actions** tab, choose **Build AttendGuard demo APK**, run it.
3. Download artifact **AttendGuard-demo-APK** and install `app-release.apk` on a
   real Android phone. Approve Nearby Devices permission; switch Bluetooth on.
4. Tap **Simulate beacon (test only)**. Check the class card, one-tap button and
   the **Test 60s re-check prompt**. For real ESP32, scan a beacon with the correct
   advertising protocol and observe a class card backed by mocked course data.

GitHub Actions runs `flutter create` to generate `android/` and pubspec on its
Linux runner, then installs dependencies, applies permissions, tests and compiles.
This keeps the download small and avoids requiring a local SDK. The code is a
**starter scaffold**, not a precompiled APK or a verified production release.

## For the backend team

See **BEACON_AND_BACKEND_CONTRACT.md** for the exact bytes and callable Functions.
- Session data and code are server-side.
- Only Cloud Functions write attendance.
- Enforce student role, enrollment and device binding on every server call.
- Students cannot read `sessionSecrets` or other students' attendance.
- Functions region must match the Flutter Firebase Functions instance (default
  `us-central1`, unless your backend changes this).

## Live app build

The optional **Build AttendGuard live APK (Firebase)** workflow needs four
repository Actions secrets, listed in **UPLOAD_FROM_WINDOWS.md**. They are client
configuration and do not grant admin access. Never supply a service-account key.
The live APK still requires a deployed backend and test user account to be useful.
The generated Android package ID is `com.example.attendguard` (hackathon-only);
ask the Firebase teammate to register that Android application ID, or change
it consistently in the build before configuring Firebase.

This is a hackathon APK using the Flutter-generated Android signing setup,
**not a signed Google Play production release**.

## Security

Read **SECURITY.md** before setting repository visibility to Public. Automated
checks (`python3 scripts/check_public_repo.py`) block common credentials and
sensitive file names, but cannot certify the absence of every possible leak.

## Limitations

- Android real device only; foreground scanning. No iPhone support.
- The session code is carried in BLE advertising and can be relayed by an
  attacker. This demo is proxy-resistant, not relay-proof.
- The device ID is a best-effort install/device binding, not hardware attestation.
- Uses `flutter_blue_plus` (license terms apply; educational use is free per
  current package page).
