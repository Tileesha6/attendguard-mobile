# 48-hour priorities for the app developer

- **Hours 0–4:** Install Flutter/SDK; enable USB debugging; generate project; copy source; `flutter run -t lib/main_demo.dart` on real phone. Screenshot successful local UI.
- **Hours 4–10:** Verify BLE scanner with teammate's ESP32 using nRF Connect, then see a "CS101" test class in app in demo mode.
- **Hours 10–18:** Connect to the team's actual Firebase project; sign in with seeded test student; test `lookupSession` and `markPresent` on a live session.
- **Hours 18–27:** Test wrong code / unenrolled student / repeat mark / device mismatch and dashboard review. Fix permissions and malformed advertisements.
- **Hours 27–36:** Test manual re-check and full-screen timer on real phone while the lecturer triggers it on the web dashboard. Test success and timeout.
- **Hours 36–42:** Resolve Android device quirks, use hotspot and build release APK. If time remains, implement attendance history by aligning Firestore queries with security rules.
- **Hours 42–48:** Freeze scope, full rehearsal, record the demo and keep an APK plus source backup.

Do not build push notifications, automatic random re-checks, rotating codes or background BLE before the core check-in works.
