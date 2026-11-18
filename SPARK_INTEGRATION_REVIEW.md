# AttendGuard — Spark direct-Firestore integration review and change log

**Target Flutter repository:** `Tileesha6/attendguard-mobile`  
**Target Firebase project:** `iteration-346ad`  
**Lecturer dashboard:** https://iteration-346ad.web.app  
**Mode:** Spark / Direct Firestore / no deployed Cloud Functions  
**Status:** Proposed compatibility update; **not** a deployed or hardware-validated release.

## Executive decision

The team leader's idea is **feasible for a hackathon attendance demonstration but weak as an anti-proxy security design**. Restricting collection `list` does not guarantee that a mobile phone heard an actual ESP32 broadcast. The session code *is* the readable document ID and has only eight decimal digits. A remotely supplied or guessed code can be used to fetch the session. A mobile device identifier is generated and supplied by the mobile client and can be changed by a modified client, reinstall, or reset. Name and optional student ID are not authenticated. With no Firebase Auth required, the rules cannot establish student identity.

The original app, by contrast, uses Firebase Auth, role-enforced callable Functions, enrollment checks, device binding, and optional 60-second rechecks. These stronger protections cannot all be preserved with the leader's minimal schema and no trusted server.

**Recommendation:** Use the new scheme only as a **prototype**, clearly state its limitations, and plan an authenticated student-UID keyed schema for any real university rollout.

## Comparison: actual app vs leader's instruction

| Requirement / proposed change | Before | Change in this patch | Residual issue |
|---|---|---|---|
| BLE manufacturer `0xFFFF`, marker `0xA7`, big-endian 4 bytes | Implemented | Retained | Must test with physical ESP32 |
| Reject `00000000` | Missing (zero was accepted) | **Implemented** | None in parser |
| Support 7-byte `[FF FF A7 ...]` payload representation | Missing | **Implemented** | Depends on Bluetooth library payload representation |
| Connect to project `iteration-346ad` | Build-time project settings; not guaranteed | Project ID default and explicit project validation | Requires valid *Android* Firebase credentials |
| Hardcode leader's `:web:` Firebase App ID in Android | Not implemented | **Intentionally NOT done** | Must register Android Firebase app |
| No deployed Cloud Functions on Spark | Existing mobile adapter calls Cloud Functions | Direct Firestore adapter added and selected by default | Original backend preserved for callable mode |
| Exact read: `sessions/{code}.get()` | `lookupSession` callable | **Implemented** | Public document `get` exposes session if code known |
| Check session `status == live` | Verified in callable backend | **Implemented** | Rules still must validate when creating attendance |
| Check existing `attendance/{deviceId}` | Callables use user UID | **Implemented** in lookup | Not reliable physical-device identification |
| Create record `attendance/{deviceId}` | Callable `markPresent` | **Implemented** direct transaction, six required fields | Rules must enforce *create-only* and valid data |
| Name required, Student ID optional | Account login, no name field | **Implemented**; stored locally | Fields are self-asserted, not verified |
| No pre-enrollment | Original backend required enrollment | Direct mode skips enrollment | Weakens student identity controls |
| No login for student check-in | Email/password required | Direct mode bypasses LoginScreen | No authenticated identity; serious security compromise |
| One check-in per device | Device binding checks through backend | Duplicate document ID checked; create-only rules expected | Client can provide a different `deviceId`; reinstall can change ID |
| 60-second rechecks removed | Recheck UI and callable exist | Direct mode disables listener; original code retained | Valuable anti-proxy deterrent lost |
| Live dashboard shows records | Backend already tested in local emulator | Writes team leader's expected schema | Requires real cross-device verification |
| Attendance data privacy | Prior backend limits reads | New contract allows public document gets | Sensitive data can leak if record ID discovered |
| Roles for lecturer/admin | Custom claims in original backend | Mobile does not change dashboard role auth | Inspect actual rules/role provisioning separately |

### Exact Firestore document contract now used in direct mode

```
sessions/{eightDigitCode}
  status: "live"            # provided by lecturer dashboard
  # optional courseCode/courseName/hallName for mobile display

sessions/{eightDigitCode}/attendance/{hashedInstallDeviceId}
  code: "12345678"
  studentName: "Full Name"
  studentId: "IT260001"     # optional, may be empty string
  deviceId: "<hashed install identifier>"
  status: "present"
  checkedInAt: serverTimestamp()
```

For the leader's `get`-only session rules, **do not run a `.where` query**. The direct adapter reads `sessions/{code}` and `attendance/{deviceId}` only. Local code checks for duplicate documents and uses a transaction; the **rules must deny direct updates/deletes** so an edited client cannot overwrite existing records.

## Firebase Android configuration — important correction

The provided value `1:292856811328:web:dc8887a98f96f03fbe74a5` identifies a **WEB** app, not an Android app. It is unsafe to assume it works for Android initialization; do not hardcode it in `lib/main.dart` or GitHub Secrets. Firebase requires app-specific configuration for an Android app.

1. In **Firebase Console → iteration-346ad → Project settings → Your apps**, register an **Android** app with the exact package ID produced by the APK build (`com.example.attendguard` is the current generated project's documented package name; verify it before registration).
2. Obtain the Android `google-services.json` and/or run `flutterfire configure --project=iteration-346ad` in an actual Flutter Android project to generate the correct Android Firebase options.
3. Set these GitHub Actions secrets in the **phone repo**, not in the backend repo:
   - `FIREBASE_PROJECT_ID=iteration-346ad`
   - `FIREBASE_SENDER_ID=292856811328` (the workflow uses **SENDER**, not `FIREBASE_MESSAGING_SENDER_ID`)
   - `FIREBASE_API_KEY` = Android app's configured client key
   - `FIREBASE_APP_ID` = registered **Android** app ID (`1:292856811328:android:...`)
4. The workflow will now reject a `:web:` ID or wrong project ID before building an APK.
5. Do **not** commit service-account JSON, admin keys, or passwords. Firebase client API keys are public identifiers, but should still be the correct platform's configuration.

## What to confirm with the leader before declaring it complete

- Does `iteration-346ad` have a Firestore **default database** and do its *actual deployed* rules allow `get` on `sessions/{code}`, `get` on `attendance/{deviceId}`, and **create-only** attendance writes without Auth?
- Do the rules validate `request.resource.data.keys()` and enforce `studentName` nonempty, `studentId`, `deviceId`, `status == 'present'`, code match, `checkedInAt == request.time`, `status == 'live'`? Merely sending these fields in the app is not secure enforcement.
- Does the dashboard create documents with the 8-digit **code itself as the session document ID**? An auto-generated `sessionId` will **not** work with this patch.
- Is the dashboard writing optional `courseCode`, `courseName`, and `hallName`? The provided minimal schema doesn't contain them. This patch displays generic labels when absent.
- Is the dashboard listening to `sessions/{code}/attendance` and rendering `studentName`, `studentId`, `deviceId`, `checkedInAt`?
- Are staff accounts authorized by a protected UID/custom claim? **Do not rely only on user-editable profile fields.**
- Does dashboard stop/close an attendance session by changing `status` to `ended`?
- Has the team tested different phones, network loss, double taps, app reinstall, malicious altered `deviceId`, and attempts to read another student's records?

## Security findings: unresolved by the team leader's design

**CRITICAL — No attendance identity verification.** Students can enter anyone's name/ID. Direct writes with no Auth cannot establish who submitted them. A signed-in anonymous user would still not establish an enrolled university identity.

**HIGH — Code knowledge is not BLE proximity.** Denying `list` prevents straightforward enumeration but `allow get: if true` on a document named with the eight-digit code permits remote `get` of known/guessed codes. Codes are susceptible to sharing, relay and online guessing. An 8-digit code has a maximum of 100 million possible values (and dashboard-generated 10000000–99999999 has 90 million).

**HIGH — Device lock is advisory.** `attendance/{deviceId}` enforces one record per **supplied string**, not necessarily per physical phone or person. A modified client can invent a new `deviceId`; reinstalling can generate another installation ID. The client must never claim this is a secure unique hardware identity.

**HIGH — Public record `get`.** If the rules allow unauthenticated `get` on `attendance/{deviceId}`, anyone who learns the ID can read stored student names, IDs and check-in times. Access should be restricted in a production design.

**MEDIUM — No re-check challenge.** The simplified system drops the existing 60-second verification. A previously heard code can be reused remotely while the session is live.

**MEDIUM — Staff by email.** If the actual rules use a small set of hardcoded lecturer email addresses, review sign-in method, email verification and claims. Long-term roles should use protected UIDs/custom claims, not just unverified profile/email strings.

**HIGH — App platform ID.** The supplied `:web:` App ID is not the registered Android application identity. The build now explicitly rejects it.

### Recommended safe evolution while retaining Spark

Keep email/password student authentication and bind records to **`request.auth.uid`**. Create and manage lecturer roles using trusted admin provisioning (protected UIDs or custom claims), enroll known students where possible, restrict attendance reads to the owner and staff, and write immutable records. Add App Check where feasible. None of these measures makes BLE codes cryptographically prove presence; meaningful anti-relay/device attestation requires stronger trusted infrastructure and a different protocol.

## Applying this patch locally

Run in PowerShell after downloading/extracting this patch and before making changes:

```powershell
cd "$HOME\Documents\attendguard-mobile"
git status --short
py "$HOME\Downloads\AttendGuard_Spark_Patch\apply_spark_update.py" --repo "$HOME\Documents\attendguard-mobile"
```

To apply, only if the dry run reports **Preflight OK**:

```powershell
py "$HOME\Downloads\AttendGuard_Spark_Patch\apply_spark_update.py" --repo "$HOME\Documents\attendguard-mobile" --apply
git diff --check
git diff --stat
```

The apply script backs up original files **outside** your checkout. It changes eight items: `lib/main.dart`, `lib/app.dart`, `lib/services/backend.dart`, `lib/services/beacon_parser.dart`, `lib/screens/home_screen.dart`, `.github/workflows/live-apk.yml`, `test/beacon_parser_test.dart`, and this report.

After configuring Android-specific Firebase secrets, trigger the existing `Build AttendGuard REAL attendance APK (Firebase)` GitHub Actions workflow. It will use **Direct Firestore**; it will not attempt Cloud Functions. The existing hardware test workflow remains untouched.

### Hardware end-to-end acceptance

1. ESP32 advertises manufacturer data `FF FF A7 00 BC 61 4E` for code `12345678` and scanner detects it.
2. Dashboard creates `sessions/12345678` with `status: live` on `iteration-346ad`.
3. Live Android APK initializes using a registered **Android** Firebase App ID; no email/password UI appears in Spark mode.
4. Phone detects the beacon, reads `sessions/12345678` using `get`, displays *live session*, and requests non-empty name plus optional ID.
5. On tap, Firestore creates `sessions/12345678/attendance/{deviceId}` with exact six fields and server timestamp.
6. Lecturer dashboard shows name/ID live. A second tap / same ID cannot overwrite the document.
7. End session, retry submission: Firestore rules must deny new attendance.
8. Test using a spoofed new device ID to **demonstrate the known unresolved security limitation**, not claim the system is proxy-proof.

## Validation status

- **Read-only repository comparison:** Completed against the files retrieved from the GitHub default branch.
- **Patch script Python syntax:** Validated in the package environment.
- **Dart compile / Flutter tests:** **Not executed here** (Flutter/Dart SDK unavailable).
- **Firebase production rules:** **Not inspected/deployed** for project `iteration-346ad`.
- **GitHub remote write:** **Not performed** (connector denied branch creation with HTTP 403).
- **Android, ESP32, live dashboard end-to-end:** **Not yet tested**.

This is a working-source *proposal* for the team's new contract, not a certification that the deployed system is secure or functioning end-to-end.
