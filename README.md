# AttendGuard — Mobile app (BLE hardware-test update)

**Hackathon Android source.** The local APK can scan real ESP32 manufacturer BLE advertisements offline. No committed credentials or `.env` files. [Read the full change list](CHANGES_V2.md).

## Fast track: update your existing GitHub repository

Download `AttendGuard_Changes_Only.zip` and follow **[UPDATE_FROM_POWERSHELL.md](UPDATE_FROM_POWERSHELL.md)**. This preserves your existing repo and lets GitHub Actions build the test APK.

## What the test APK does

- Requests Android Nearby Devices permission and, when Bluetooth is off, requests system approval to enable it (not silent).
- Automatically scans while the app is in the foreground; restarts on return to the foreground.
- Detects **any** valid ESP32 code matching manufacturer ID `0xFFFF`, marker `0xA7`, and 4 big-endian bytes.
- Displays the code, RSSI, and detection time in a **BLE Test** tab, with explicit real-vs-simulated labels.
- Supports manual code simulation for interface testing only; it **does not modify ESP32 or Firebase**.
- Shows a mock course and fake Mark Present to demonstrate student UX. It never records real attendance.

## What the real Firebase app does

The `lib/main.dart` entrypoint uses the team's Firebase callable functions to look up and verify the session, enrolled student and device binding. The live app hides raw codes. Backend deployment and authentication are separate responsibilities; see [BEACON_AND_BACKEND_CONTRACT.md](BEACON_AND_BACKEND_CONTRACT.md).

## What the mobile app cannot do

The ESP32 broadcast code is changed by the **lecturer dashboard over USB Serial**, not by the student app. A secure phone-based admin controller would need authenticated server actions and a new transport to the beacon. We have not added a fake admin password or insecure client-side code override.

## Security and builds

GitHub Actions uses Java **21** and `permission_handler:12.0.3` (matching the dependency and Android Lint fixes). A successful GitHub build and a hardware test on your Android phone are still needed — these have **not** been run here. Read **SECURITY.md**, **CHANGES_V2.md**, and **UPDATE_FROM_POWERSHELL.md** before publishing.

