# Public repository security policy

This project intentionally ships **without** `.env`, `.env.local`, private API keys,
Firebase service-account credentials, Firebase Android config files,
keystore files or any real student data. `lib/main.dart` obtains the **Firebase
client configuration** through build-time `--dart-define` values, not a committed file.

**Important:** Firebase client API keys are not authentication secrets. They are
embedded in the distributed Android APK and can be extracted; GitHub Secrets only
keeps them out of the repository and build logs. Do not use these as server-side
secrets. Enforce authentication, authorization, Firestore Security Rules and
Cloud Functions checks server-side. Firebase App Check is recommended when feasible.

Never store or upload:
- Admin SDK service account JSON or Google Cloud private keys.
- Real user passwords, lecturer admin tokens or attendance exports.
- GitHub personal access tokens or signing keystores.
- `.env` or machine-specific configuration containing credentials.

Before a public push, run `python3 scripts/check_public_repo.py`. The demo APK
workflow also runs it automatically. This scanner checks only common patterns:
**manual review and GitHub's secret scanning remain necessary**.

If a secret was already committed, **deleting it in a later commit is not enough**.
Revoke or rotate it at its provider, then remove it from history if appropriate.

Deploy Cloud Functions and database rules from the backend teammate's controlled
repository. The phone app must never create attendance records directly.

References:
- https://firebase.google.com/docs/projects/api-keys
- https://firebase.google.com/docs/rules
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
