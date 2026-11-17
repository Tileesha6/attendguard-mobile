# Initial source audit (2026-11-17)

## What was reviewed

- All files included in this public GitHub starter package.
- Secret file names, `.env` paths, known token patterns and private-key headers.
- Android BLE permissions patch, GitHub Actions YAML structure and the test-mode
  separation from Firebase-backed attendance.
- Source-level use of the manufacturer-data format from the project handoff.

## Findings

- **No real API credentials, `.env` files, signing keys or service account JSON
  files are present in this release package.**
- A `.gitignore` blocks common local secrets from ordinary Git commits.
- Both GitHub Actions workflows run a credential-pattern check before building.
- The demo target cannot write attendance to Firebase: it uses a deliberately
  fake backend. Live mode uses callable Cloud Functions with Firebase Auth.
- Test included for the advertised 8-digit BLE sample and leading zero padding.

## Honest limitations

- Static scans detect common issues, not every secret format or vulnerability.
- There is no Flutter/Android SDK in this authoring environment, so this release
  **has not been compiled on Android or verified on a phone**. The uploaded
  GitHub Actions workflow performs the first actual package installation,
  parser unit tests and APK compilation. If Actions reports an error, fix it
  before describing the APK as working.
- Real Firebase login, database rules and Cloud Functions must be provided
  and tested by the backend team. A repository can be secret-free while the
  deployed backend still has unsafe permissions; backend review is separate.
- BLE broadcasting is proximity evidence, not relay-proof location attestation.
