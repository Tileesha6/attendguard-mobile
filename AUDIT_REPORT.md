# AttendGuard source audit — BLE test update

Checked: 2026-11-17

## Static checks completed

- Inspected source files in the existing public GitHub starter, including `.github/workflows`, Dart screens/services and the Android permissions patch.
- Updated demo and live GitHub workflows to Java 21 and `permission_handler:12.0.3`, matching the user's previous CI fixes.
- Included no `.env`, keystore, Firebase service account, `google-services.json`, credentials, or API token in this project ZIP.
- Ran `python3 scripts/check_public_repo.py` on the updated source; no matched credentials or disallowed files.
- Tested the BLE manufacturer payload arithmetic with sample codes `12345678` and `87654321` using a local Python fixture. Flutter parser and BLE Test widget tests are included, but **Flutter tests have not been run here**.

## Caveats

- This is a static packaging audit only. It is **not** a guarantee that no API secrets could ever be leaked or that all code paths are vulnerability-free.
- Flutter/Dart SDK and a real Android device were not available in this container. **No APK was compiled or installed.** GitHub Actions must verify compilation and device tests must verify actual detection and OS Bluetooth prompts.
- Firebase client configuration passed through dart-defines is extractable from an APK; that is normal for mobile clients. Real security must be enforced with Firebase Auth, server-side Cloud Functions validation and Firestore rules.
- Debug APK reveals received BLE codes. **Do not distribute it as the production attendance client.** The live application intentionally hides the code.
- The Android system requests consent to enable Bluetooth. The app cannot force Bluetooth on without permission.
- The source `0xFFFF` manufacturer ID is reserved for prototyping and does not authenticate the ESP32 itself.

## Confirmation needed on GitHub

1. The public repository check passes on updated code.
2. The Flutter parser tests pass.
3. The release APK builds successfully with Java 21 on the runner.
4. A real Android phone shows the requested Bluetooth enable prompt and receives code from the ESP32 (not merely a mock code).
