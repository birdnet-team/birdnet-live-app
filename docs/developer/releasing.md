# Releasing

End-to-end recipe for cutting a Play Store release. The Flutter side is
straightforward; most of the moving parts are around signing and the
artifacts that go into the `release/` folder.

## 1. Version

`pubspec.yaml` is the **single source of truth** for the version. The patch
number doubles as the build number (`+`-suffix), so a typical bump looks like:

```yaml
version: 0.15.3+161
```

After editing, propagate the version to the README badge, MkDocs home badges,
and any other generated references:

```pwsh
dart dev/sync_version.dart
```

## 2. Pre-flight checklist

1. Update `CHANGELOG.md` — every user-visible change goes under the new
   version heading, grouped into Added / Changed / Fixed.
2. Bump `pubspec.yaml` and run `dart dev/sync_version.dart`.
3. Confirm the Git LFS model files are present with `git lfs pull` on fresh
  checkouts or release machines.
4. `flutter analyze` — must report **No issues found!**.
5. `flutter test` — full suite must pass.
6. Sanity-check the app on a physical Android device with `flutter run
   --release` (the release build behaves differently from debug for ONNX
   Runtime memory mapping and ProGuard).

## 3. Signing

Release builds are signed via `android/key.properties` (gitignored). The file
points the Gradle build at the upload keystore and looks like:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

`android/app/build.gradle` reads this file and falls back to debug signing if
the keystore is missing — so contributors can still build locally without the
upload key. **Never commit `key.properties` or the `.jks` file.**

If you ever lose the upload key, you can request a key reset from Play
Console (Google holds the actual app-signing key in Play App Signing).

## 4. Build Android Artifacts

The Play Store expects an `.aab`, not an APK. App Bundles deliver only the
target device's ABI and resources, which trims our ~253 MB APK to ~221 MB on
device.

Use the helper script — it builds, verifies, stages every artifact into
`release/V<version>/`, and prepares the notes:

```pwsh
dart dev/build_release.dart --since <last-play-version>
```

`--since` is **required**: it is the version currently live on Google Play.
See [Release notes](#release-notes) for why.

| Flag | Purpose |
| ---- | ------- |
| `--since <version>` | Version currently live on Play, e.g. `1.0.1`. Required. |
| `--notes-only` | Regenerate the notes files without rebuilding the bundle. |

The Flutter SDK must be on `PATH` — `flutter --version` has to work in the same
shell. The script shells out to `flutter.bat` on Windows and will stop with a
clear error if it cannot find it.

Under the hood it runs these signed builds:

```pwsh
flutter build appbundle --release `
  --obfuscate --split-debug-info=build/symbols/V<version>
flutter build apk --release
```

Windows quirk: the Java toolchain prints obsolete-options warnings that make
`javac` return a non-zero exit code even when Gradle succeeded. The script
therefore verifies the AAB on disk rather than trusting the exit code — do the
same if you build by hand.

Output:

- Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- ProGuard / R8 mapping: `build/app/outputs/mapping/release/mapping.txt`

The mapping file is critical: without it, Play Console cannot de-obfuscate
stack traces from crash reports, leaving you unable to tell what's broken in
the field.

The helper also creates a square 512 x 512 PNG from the launcher artwork for
Huawei AppGallery.

## 5. Stage the release artifacts

`dev/build_release.dart` does this for you. The result lives in a versioned
folder under `release/` (gitignored except for `.gitignore` itself):

```
release/V1.0.3/
  BirdNET_Live_V1.0.3.aab
  BirdNET_Live_V1.0.3.apk
  BirdNET_Live_V1.0.3_icon_512.png
  mapping.txt
  release_notes.txt          # the deliverable — one block per locale
  release_notes.source.txt   # reference digest, never uploaded
  symbols/
    app.android-arm.symbols
    app.android-arm64.symbols
    app.android-x64.symbols
```

Keep this folder around — it is the canonical record of what was uploaded.
If you need to roll back or re-symbolicate a crash months later, the
`mapping.txt` for the exact build running on users' devices is the only thing
that matters.

### Release notes

**We do not ship every tagged version to Play.** Uploads go out roughly weekly,
so one Play release usually covers several CHANGELOG entries. That is why
`--since` exists and why it cannot be inferred: the repo has no record of which
version is actually live on the store, so whoever cuts the release has to say.

Check the live version in Play Console → Production → Releases before running
the script. Getting it wrong doesn't break the build, it just means the notes
describe the wrong span of work.

Two files are produced:

- **`release_notes.source.txt`** — every CHANGELOG bullet between `--since` and
  the current version, grouped by version. Regenerated on every run. Reference
  only; never paste it into Play Console.
- **`release_notes.txt`** — the deliverable. Only created when absent, so your
  edits and translations survive a rebuild.

Write the `<en-US>` block as **a single high-level line** covering everything
since the last Play release — not a bullet dump, and not a per-version
changelog. Store visitors want "what is different for me", so summarise:

```
<en-US>
Adds a way to ignore species you don't want reported, and fixes a crash when starting a recording.
</en-US>
```

Then translate that one line into the other 11 locales. Max ~500 characters per
locale (the Play limit); the script's budget is 480 to leave room for
translations that run longer than the English. All 12 locales the app ships in
get a block: en-US, de-DE, cs-CZ, es-ES, fr-FR, it-IT, nl-NL, nb-NO, pl-PL,
pt-PT, ru-RU, zh-CN. Any locale missing on Play Console falls back to en-US.
Write zh-CN in Simplified Chinese characters, never pinyin.

Resist auto-generating this text. An earlier version of the script filled the
en-US block from the changelog and, because of a parsing bug, silently shipped
"Stability and polish improvements." on every release for months.

## 6. Upload to Play Console

1. Open Play Console → Internal testing (or Closed testing / Production).
2. Note the version currently live — that is the `--since` value for the *next*
   release.
3. Create a new release.
4. Upload `release/V<version>/BirdNET_Live_V<version>.aab`.
5. Upload `release/V<version>/mapping.txt` under "App bundles → ⋮ → Upload
   deobfuscation file".
6. Paste each block from `release_notes.txt` into the matching language slot.
   Every `TODO:` must be gone first.
7. Review → roll out.

For first-time upload to a new track, expect a 1–2 hour review delay.

## 7. Upload to Huawei AppGallery

1. Create a new AppGallery release and upload
  `release/V<version>/BirdNET_Live_V<version>.apk`.
2. Upload `release/V<version>/BirdNET_Live_V<version>_icon_512.png` as the
  512 x 512 app icon.
3. Use the same reviewed user-facing release notes as the Play release.

## 8. Tag and push

After the release is live (or queued for review), tag the commit:

```pwsh
git tag v0.15.2
git push origin v0.15.2
```

Tags are the easiest way to map a Play Console version code back to its exact
source commit.

## 9. Post-release

- Watch the Play Console **Vitals** tab for the first 24–48 h. ANRs and
  native crashes show up here first.
- If a crash report comes in, locate the matching `release/<version>/mapping.txt`
  and upload it via Play Console (or use `retrace` locally) to symbolicate
  the stack trace.

## iOS

iOS builds and App Store/TestFlight releases require a macOS environment with Xcode installed.

### 1. Prerequisites and Signing
- **Apple Developer Account**: Signing certificates and provisioning profiles are configured via the team Apple Developer portal.
- **Xcode Integration**: Open `ios/Runner.xcworkspace` in Xcode and under the **Runner** target → **Signing & Capabilities**, make sure the correct **Development Team** is selected and the Bundle Identifier (`com.birdnet.birdnetLive` or your custom identifier) is registered.

### 2. Build the iOS Archive
To compile the project and generate the release xcarchive with symbols, run:

```bash
# Pull model assets if needed
git lfs pull

# Build the release archive and export symbols
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/V0.16.0-ios
```

This generates:
- An xcarchive folder at `build/ios/archive/Runner.xcarchive`.
- A signed `.ipa` package under `build/ios/ipa/` (if provisioning is configured).
- Obfuscation symbols under `build/symbols/V0.16.0-ios`.

### 3. Archive and Distribute via Xcode
If direct command-line exporting is not configured:
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Any iOS Device (arm64)** as the build destination.
3. Choose **Product → Archive** from the menu.
4. Once the archive is complete, the Xcode Organizer window will open. Click **Distribute App** and follow the prompts to upload the build to App Store Connect / TestFlight.

### 4. Upload Native Symbols (dSYMs)
Native crash reports (including ONNX Runtime native issues) require dSYM files for symbolication:
- During standard App Store submission from Xcode or Organizer, check the **"Upload your app's symbols to receive sentry/crash reports"** box.
- Alternatively, retrieve the dSYMs from the `.xcarchive` bundles (under `dSYMs/`) and upload them to your crash reporting system.
