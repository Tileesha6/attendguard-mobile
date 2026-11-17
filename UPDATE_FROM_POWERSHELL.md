# Update an existing AttendGuard GitHub repository from Windows PowerShell

Your existing repository is at `C:\Users\User\Documents\attendguard-mobile`, with remote `Tileesha6/attendguard-mobile`. The update ZIP has only the files that changed, so it leaves your `.git` directory, Firebase configuration, and unrelated local files untouched.

1. Download `AttendGuard_Changes_Only.zip` into your Windows **Downloads** folder.
2. Run the following in PowerShell:

```powershell
cd "$HOME\Documents\attendguard-mobile"

# Inspect your working tree first. Avoid overwriting uncommitted edits.
git status --short

# Restore the original source from Git if you accidentally edited a file.
# Do NOT run a blanket git reset; it may erase your work.

# Expand the patch over the current repository.
Expand-Archive -Path "$HOME\Downloads\AttendGuard_Changes_Only.zip" `
  -DestinationPath "$HOME\Documents\attendguard-mobile" -Force

# Review edits and check for exposed secrets.
git status --short
git diff --stat
py scripts/check_public_repo.py

# Stage only the known source, tests, workflow and documentation paths.
git add lib/screens/home_screen.dart lib/screens/beacon_test_panel.dart `
  lib/services/ble_service.dart test/beacon_parser_test.dart `
  test/beacon_test_panel_test.dart `
  .github/workflows/demo-apk.yml .github/workflows/live-apk.yml `
  README.md CHANGES_V2.md UPDATE_FROM_POWERSHELL.md

git diff --cached --name-only
git commit -m "Add offline BLE test mode and automatic Bluetooth scan"
git push origin main
```

3. Open `https://github.com/Tileesha6/attendguard-mobile/actions`.
4. Open the latest **Build AttendGuard demo APK** workflow. If successful, download the APK from **Artifacts**.
5. If the build fails, run:

```powershell
gh run list --repo Tileesha6/attendguard-mobile --limit 3
$runId = gh run list --repo Tileesha6/attendguard-mobile --limit 1 --json databaseId --jq '.[0].databaseId'
gh run view $runId --repo Tileesha6/attendguard-mobile --log-failed | Select-Object -Last 100
```

**Note:** This project uses GitHub Actions to create an Android project from source. Do not add server credentials or `.env` files to GitHub. The BLE Test tab is for the demo APK only, not for students using the live APK.
