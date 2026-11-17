# AttendGuard — Real Android attendance app

This repository contains the **real Flutter student app**, not just a demo UI. The app is ready to connect to the team's Firebase backend and ESP32 hardware.

**Read [SHIP_REAL_APP.md](SHIP_REAL_APP.md) for the Thursday deployment checklist and exact Windows PowerShell commands.**

## Two build targets, two separate purposes

- **ESP32 Hardware Test APK** (`lib/main_hardware_test.dart`, automatic build on push): scans **real** Bluetooth manufacturer advertisements, shows received 8-digit codes and RSSI, works offline. No simulated codes and no attendance claims.
- **REAL Firebase Attendance APK** (`lib/main.dart`, manually triggered): Firebase Authentication, Bluetooth scanning, server-verified class lookup, check-in via callable Cloud Functions, 60-second re-check confirmation, student device binding. Requires team backend and Firebase configuration.

The source also includes an older `main_demo.dart` for internal UI prototyping, but **neither shipping workflow uses it**. Do not install it as the final app.

The ESP32 and protocol are documented in [BEACON_AND_BACKEND_CONTRACT.md](BEACON_AND_BACKEND_CONTRACT.md). GitHub CI uses Java 21 and a compatible `permission_handler` version. The phone must be a real Android device with BLE capabilities.

## Public repository precautions

No `.env`, Firebase Admin credentials, keystores, or private keys should be uploaded. Run `py scripts/check_public_repo.py` before pushing, and examine `git diff --cached --name-only`. Firebase API keys included in an Android APK are **public client configuration**; authorization must be enforced by Firebase Security Rules and Cloud Functions. See [SECURITY.md](SECURITY.md).

## Server expectations

The backend team must deploy the authenticated callable functions `lookupSession`, `markPresent`, `confirmRecheck` and rules for `sessions/{id}/rounds`. The lecturer dashboard starts sessions and sends the random code over USB to the ESP32. If these are not live, the mobile app **cannot honestly claim to record attendance**. The BLE hardware tester can still validate the antenna, BLE permissions, and manufacturer payload.
