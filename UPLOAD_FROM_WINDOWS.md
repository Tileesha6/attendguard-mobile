# Upload AttendGuard to your PUBLIC GitHub repo (Windows)

Use **GitHub Desktop** for the most reliable way to upload nested files and
`.github/workflows` without installing Flutter or using a terminal.

## Option A — GitHub Desktop (recommended)

1. Create an empty **Public** repository at https://github.com/new named
   `attendguard-mobile`. Do **not** initialize it with a README, .gitignore or license.
2. Download and install GitHub Desktop: https://desktop.github.com/ . Sign in.
3. In GitHub Desktop, choose **File → Clone repository**, select
   `attendguard-mobile`, and choose a local folder (for example
   `Documents\\GitHub\\attendguard-mobile`). Click **Clone**.
4. On Windows, right-click the downloaded ZIP → **Extract All**.
5. Open the extracted `AttendGuard_Public_GitHub_Safe` folder. **Copy the contents**
   (including hidden `.github` and `.gitignore`) into the cloned repository folder.
   Do not copy the outer folder. You want `README.md`, `lib/`, `scripts/`, and
   `.github/` directly at the root of `attendguard-mobile`.
6. Return to GitHub Desktop. You should see the changed files. Before publishing,
   check that there is **NO `.env`, `google-services.json`, service-account JSON,
   passwords or keystore** in its Changes list.
7. Enter a summary `Initial AttendGuard Flutter student app` → **Commit to main**.
8. Click **Push origin**. Open the repository in your browser, verify
   `.github/workflows/demo-apk.yml` is present.
9. Go to **Actions → Build AttendGuard demo APK → Run workflow** (or inspect
   the automatic run triggered by the push).
10. When the run is green, open it → **Artifacts** → download
   `AttendGuard-demo-APK` → unzip → transfer `app-release.apk` to your phone → install.
    It is a **local demo**, not real server-backed attendance.

## Option B — GitHub website (without installing GitHub Desktop)

1. Unzip the archive on your PC.
2. Open your repo's main page and choose **Add file → Upload files**.
3. Drag the extracted **folder's contents** onto the upload area. Check that
   directories `lib/`, `scripts/`, `test/`, and `.github/workflows/` are preserved.
4. Review the staged file list carefully for secrets. Commit directly to `main`.
5. Confirm `https://github.com/YOUR_USERNAME/attendguard-mobile/blob/main/.github/workflows/demo-apk.yml`
   opens successfully; if not, upload that file at the correct folder path.
6. Follow Actions steps 9–10 above. GitHub web upload does **not** honor `.gitignore`
   as Git does, so **never select any credential file** for upload.

## Future real Firebase app (after backend is ready)

Your backend teammate supplies four Firebase **client configuration** values:
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID`.
In GitHub → repo **Settings → Secrets and variables → Actions**, add each under
**Repository secrets** (these are not server-side secrets). Then run the
**Build AttendGuard live APK (Firebase)** workflow. This builds `lib/main.dart`.

Ask the backend teammate to register the Android application ID
`com.example.attendguard` in Firebase for this generated app. If they use a
different package ID, the build must be updated to match.

**Do not enter any Admin SDK JSON, private key, service account key or password.**
GitHub Secrets are an upload/build mechanism, not a way to hide values from the
installed APK. The live workflow cannot work before the backend functions,
Firestore access rules, and enrolled test student account exist.

## If a build fails

Open **Actions → failed run → failed step**, copy the *first actual error message*.
Build workflows use current Flutter packages; the compiler may reveal API or
Android tooling incompatibilities that require changes. No APK is included in the ZIP.
