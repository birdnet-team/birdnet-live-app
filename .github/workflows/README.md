# GitHub Actions Build and Android Signing

This folder contains CI workflows for BirdNET Live.

## CI Configuration Reference

Configure the following repository-level GitHub Actions settings in `Settings > Secrets and variables > Actions`.

### Repository Secrets

- `ANDROID_KEYSTORE_BASE64` (required for Android release signing)
- `ANDROID_STORE_PASSWORD` (required for Android release signing)
- `ANDROID_KEY_ALIAS` (required for Android release signing)
- `ANDROID_KEY_PASSWORD` (required for Android release signing)
- `WINGET_CREATE_GITHUB_TOKEN` (optional, required only for automatic Winget PR submission)

### Repository Variables

- `WINGET_AUTO_SUBMIT` (optional)
  - Set to `true` to enable automatic Winget submission.
  - Any other value keeps the manual manifest-only flow.
- `WINGET_SUBMIT_MODE` (optional)
  - `update` (default behavior when unset)
  - `new` (for first-time package submission)

### Optional CLI Setup (Secrets and Variables)

```bash
gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_STORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
gh secret set WINGET_CREATE_GITHUB_TOKEN

gh variable set WINGET_AUTO_SUBMIT --body "true"
gh variable set WINGET_SUBMIT_MODE --body "update"
```

## Android Release Signing in CI

The Android job in [build.yml](build.yml) signs the release APK using GitHub secrets.

### Secrets Required

Create these repository secrets in GitHub:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

These names must match [release.yml](release.yml) exactly.

### 1) Create a Keystore (one-time)

Use an upload key for Play App Signing (recommended), not your final app-signing key.

```bash
keytool -genkeypair \
  -v \
  -storetype JKS \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

If `keytool` is not found, install a JDK (Java 17+), then rerun.

### 2) Convert Keystore to Base64

Use one of the commands below and copy the full single-line output.

Linux:

```bash
base64 -w 0 upload-keystore.jks
```

macOS:

```bash
base64 upload-keystore.jks | tr -d '\n'
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

### 3) Add Secrets in GitHub UI

1. Open repository settings.
2. Go to `Settings > Secrets and variables > Actions`.
3. Select `New repository secret`.
4. Add each secret:
   - `ANDROID_KEYSTORE_BASE64`: base64 string from step 2
   - `ANDROID_STORE_PASSWORD`: keystore password
   - `ANDROID_KEY_ALIAS`: alias used in keytool (example: `upload`)
   - `ANDROID_KEY_PASSWORD`: key password for that alias

### 4) Optional: Add Secrets with GitHub CLI

```bash
gh secret set ANDROID_KEYSTORE_BASE64

gh secret set ANDROID_STORE_PASSWORD

gh secret set ANDROID_KEY_ALIAS

gh secret set ANDROID_KEY_PASSWORD
```

The CLI will prompt for each value.

### 5) How Signing Works in CI

During the Android build job:

1. The workflow decodes `ANDROID_KEYSTORE_BASE64` to `android/app/upload-keystore.jks`.
2. The workflow writes `android/key.properties` using the other three secrets.
3. `flutter build apk --release` uses `android/app/build.gradle`, which reads `key.properties`.
4. Temporary signing files are deleted at the end of the job.

### Security Notes

- Never commit `upload-keystore.jks` or `android/key.properties`.
- Limit who can edit repository secrets.
- Store a secure offline backup of your keystore.
- If this key is lost, app update publishing can be blocked.

## Windows Inno Setup Installer in CI

The Windows release job in [release.yml](release.yml) builds a standard Windows `.exe` installer with Inno Setup and uploads it to each GitHub Release alongside the portable `.zip` build.

### Packages Required on the Runner

The workflow installs Inno Setup with Chocolatey:

```powershell
choco install innosetup --no-progress -y
```

No Windows signing secrets are required to build the installer artifact itself.

### Local Test Build

Install Inno Setup 6 once on your Windows machine:

```powershell
winget install JRSoftware.InnoSetup
```

Then build the Windows app bundle and package it as an installer:

```powershell
.\dev\build_inno_installer.ps1
```

The script writes the installer to:

```text
build\windows\x64\runner\BirdNET_Live_v<version>_windows_x64_setup.exe
```

If you already have a fresh `flutter build windows --release` output and only want to rebuild the installer wrapper:

```powershell
.\dev\build_inno_installer.ps1 -SkipFlutterBuild
```

### Release Artifacts

The workflow now publishes two Windows artifacts:

- `BirdNET_Live_v<version>_windows_x64.zip` for portable use
- `BirdNET_Live_v<version>_windows_x64_setup.exe` for guided installation

## Winget Manifest Preparation

The release workflow generates Winget-compatible manifest files from the Windows installer for every published release.

### What Is Produced

- Workflow artifact: `winget-manifests-v<version>`
- Release asset: `winget-manifests-v<version>.zip`
- Manifest root: `release/winget/manifests/`
- Files generated for `BirdNET-Team.BirdNETLive`:
  - `BirdNET-Team.BirdNETLive.yaml`
  - `BirdNET-Team.BirdNETLive.installer.yaml`
  - `BirdNET-Team.BirdNETLive.locale.en-US.yaml`

### How To Publish To Winget

1. Download `winget-manifests-v<version>.zip` from the GitHub release (or the workflow artifact).
2. Copy the generated manifest directory into your `winget-pkgs` fork using the same path structure.
3. Open a PR from your fork to `microsoft/winget-pkgs`.

### Optional: Automatic Winget PR Submission

You can enable automatic PR creation to `microsoft/winget-pkgs` directly from the release workflow via `wingetcreate`.

Set these in your repository settings:

- Secret: `WINGET_CREATE_GITHUB_TOKEN`
  - GitHub token used by `wingetcreate` to open a PR against `winget-pkgs`.
- Variable: `WINGET_AUTO_SUBMIT`
  - Set to `true` to enable auto-submission.
- Variable: `WINGET_SUBMIT_MODE`
  - `update` (default) for existing package updates.
  - `new` for first-time package submission.

When enabled, the workflow runs one of:

- `wingetcreate update BirdNET-Team.BirdNETLive ... --submit`
- `wingetcreate new BirdNET-Team.BirdNETLive ... --submit`

If `WINGET_AUTO_SUBMIT` is not `true` or the token is missing, the workflow skips auto-submission and still publishes the manifest ZIP for manual PR flow.

### Local Manifest Generation

Use this helper script if you need to regenerate manifests locally:

```powershell
.\tools\generate_winget_manifests.ps1 `
  -PackageIdentifier 'BirdNET-Team.BirdNETLive' `
  -PackageVersion '0.16.1' `
  -InstallerUrl 'https://github.com/birdnet-team/birdnet-live-app/releases/download/v0.16.1/BirdNET_Live_v0.16.1_windows_x64_setup.exe'
```
