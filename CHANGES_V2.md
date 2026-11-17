# AttendGuard — Hackathon mobile improvements (BLE test release)

These changes are based on the team's existing Flutter source and the Anti-Proxy Smart Attendance System handoff (rev 2).

## Implemented in this package

1. **Bluetooth enable prompt:** On Android, after Nearby Devices permission is granted, the app calls the `flutter_blue_plus` Android `turnOn()` API when Bluetooth is off. **The OS requests user approval; the app never turns it on silently.** If declined or permissions denied, the UI explains the problem and offers Retry. It also listens for Bluetooth being enabled later.
2. **Automatic foreground BLE scanning:** Start on student Home screen, continue across in-app tabs, stop on app backgrounding, resume when foregrounded. One long-running scan rather than repeatedly restarting, with a status message.
3. **Offline ESP32 tester:** In the *demo APK only*, the **BLE Test** tab shows detected 8-digit code, device advertisement name, RSSI in dBm, and latest detection time. A local code simulator lets you test arbitrary eight-digit codes without Firebase or hardware; simulated records are explicitly labelled.
4. **Dynamic codes:** No session code is hardcoded as the required BLE code. The decoder accepts every valid eight-digit integer from a manufacturer advertisement with ID `0xFFFF`, marker `0xA7`, and four big-endian data bytes. The *example* `12345678` is used for an optional simulation only.
5. **First detection check-in fix:** A verified first advertisement is recorded as fresh. The old starter could occasionally require a second advertisement before Mark Present was enabled by the freshness check.
6. **Safer re-check demo and rate limits:** The local-demo re-check only accepts its current code. Firebase still validates real re-checks server-side. Lookups are rate-limited, and recent debug entries are bounded.
7. **CI repairs retained:** GitHub Actions uses Java 21 and pins `permission_handler:12.0.3`, matching the fixes discussed after build #1 and #2 errors.

## Not implemented / deliberately outside this update

- **No mobile admin login to change the ESP32's real broadcast code.** This would require an authenticated admin/lecturer backend operation and a communication link to the hardware. The current ESP32 supports code updates only over USB Serial from the lecturer dashboard. A student phone cannot change it merely by editing local settings. The Settings screen documents this.
- **No Firebase deployment or live attendance confirmation.** The demo APK's session details and attendance are simulated. The live APK still requires the team's Firebase functions, data model, security rules and credentials.
- **No background BLE scanning**, server-side code rotation, BLE distance enforcement, or iOS support.
- **No hardware test or GitHub CI compilation was run in this environment.** Verify the new APK through GitHub Actions and on a real Android phone.

## Validation steps

1. Push update to GitHub. GitHub Actions runs public-repository checks, Flutter parser/UI tests, and the release build.
2. Install **AttendGuard-demo-APK** from the successful Action run on a physical Android phone.
3. Switch Bluetooth off before opening the app. Grant Nearby devices permission. Confirm Android requests Bluetooth activation (the user must approve). If rejected, turn Bluetooth on via Quick Settings and check scan resumes.
4. Open **BLE Test**. With no ESP32, enter `12345678` and press **Simulate received code**; it must show **SIMULATED**, not a real beacon.
5. Connect the ESP32 by USB to a laptop and enter `CODE:12345678` at 115200 baud, newline. Verify it broadcasts `FFFF A7 00 BC 61 4E` (nRF Connect is another way to confirm).
6. On your phone's BLE Test tab, check a real entry appears with `12345678`, name (possibly `ATT-BEACON`), RSSI, and time. It should **not** say SIMULATED.
7. Change ESP32 Serial code to `CODE:87654321`. Confirm the BLE Test tab shows `87654321` without rebuilding the app.
8. Check Home can show a **mock** course card and that one-tap demo attendance works (no Firebase writes).
9. When integrating Firebase, ensure only the logged-in student's **server-verified** class is shown; never show the raw code in the live UI.

## ESP32 BLE packet contract

- Manufacturer ID: `0xFFFF` (test ID, not an authenticated hardware identity)
- Payload byte 0: `0xA7`
- Payload bytes 1–4: unsigned 32-bit **big-endian** integer, padded to eight digits in the app
- Example code `12345678` -> `A7 00 BC 61 4E`
- No Bluetooth pairing or GATT connection. Student phones **listen to advertisements**.

## Safety

Codes are visible **only** in the local debug APK. Don't use this build for real attendance. Production app (main.dart) does not render the code and sends it only in authenticated callable-function requests; the Firebase team must enforce security server-side.
