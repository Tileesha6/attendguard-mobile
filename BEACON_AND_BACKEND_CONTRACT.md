# Integration contract for backend and ESP32 teammates

## BLE advertisement (ESP32 teammate)

- BLE advertising only. No phone-to-ESP32 GATT connection.
- Manufacturer ID **0xFFFF** (test only), payload **exactly 5 bytes**.
- Byte 0: `0xA7` marker.
- Bytes 1–4: unsigned big-endian integer (zero-pad decimal to 8 digits).
- Handoff example: `12345678` -> `A7 00 BC 61 4E`.
- Advertise every 100–200 ms. Optional name: `ATT-BEACON`.
- Dashboard controls ESP32 via USB Serial at 115200: `CODE:12345678`.

## Callable Firebase Functions (backend teammate)

All functions use Firebase Auth and enforce `role=student` and course enrollment.
Do **not** allow the student to read `sessionSecrets/{sessionId}` or write
attendance directly.

`lookupSession({code: string})` ->
- `{found: false}` (for unknown code or not enrolled)
- or `{found: true, sessionId, courseCode, courseName, hallName, alreadyMarked}`

`markPresent({sessionId, code, deviceId})` -> `{status: 'present'|'flagged'|...}`
- Must validate live session, enrollment and current (or allowed previous) code.
- Must write atomically, idempotently.
- Must enforce device binding and flag shared/mismatching devices.

`confirmRecheck({sessionId, roundId, code, deviceId})` -> successful callable
- Checks session, enrollment, device, code, and server-side 60-second round.
- Records a `passedAt` timestamp in attendance rounds.

Firestore listener for the student's active session:

`sessions/{sessionId}/rounds/{roundId}` with
- `openedAt: Timestamp`
- `closesAt: Timestamp`
- `finalized: bool`

The student's app must have Firestore read permission for rounds of enrolled
classes. The dashboard/backend must create/finalize rounds.

## Demonstration contract test

1. Backend creates a live `CS101` session and gives `12345678` to the dashboard,
   NOT to students.
2. ESP32 sends advertisements. nRF Connect shows `FFFF A7 00 BC 61 4E`.
3. A logged-in, enrolled student's phone sees "CS101 / Demo Hall".
4. Tapping "Mark me present" invokes `markPresent` and live dashboard updates.
5. Dashboard opens `triggerRecheck`; phone sees 60-second overlay.
6. A fresh advertisement after the round opens invokes `confirmRecheck`.
7. Check-in and re-check failures are shown explicitly; no client-side bypass.
