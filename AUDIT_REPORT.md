# AttendGuard release preparation review — 2026-11-17

## Confirmed from source inspection

- The Flutter **live** entrypoint `lib/main.dart` chooses `AttendanceApp(demo: false)` and uses Firebase Auth and the `FirebaseAttendanceBackend` callable functions. It does **not** call the fake attendance backend.
- The Android **hardware-test** entrypoint `lib/main_hardware_test.dart` reads the actual `BleService.detections` stream. It has no simulated code generator, Firebase dependency, or fake attendance action.
- GitHub Actions builds the actual ESP32 hardware test APK on push using BLE-only dependencies (no Firebase plugin or mock attendance), and a separate real Firebase APK with the four GitHub Secrets on manual dispatch.
- Bluetooth protocol checks manufacturer ID `0xFFFF`, payload marker `0xA7`, and four-byte unsigned big-endian session code.
- The public-source secret scanner should be run on every change. It scans for secret-looking tokens and unsafe files, but no scanner can guarantee that every sensitive value is caught.

## Not verified in this environment

- Native Flutter/Gradle compilation and signing of these APKs (no Flutter SDK is installed here).
- Operation of real ESP32 hardware or Android BLE permissions on the user's physical phone.
- Firebase deployment and rule enforcement (Firebase project details were not supplied).
- End-to-end attendance and re-check flow on the actual team backend.

## Required signoff

A green GitHub Actions build, a real code received from ESP32, and a Firebase-backed check-in visible on the lecturer's dashboard are the acceptance criteria. Do not present the hardware-test APK as a final, server-connected attendance system.
