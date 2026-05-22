# Releasing

End-to-end recipe for cutting a Play Store release. The Flutter side is
straightforward; most of the moving parts live around signing and the
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

## 4. Build the App Bundle

The Play Store wants an `.aab`, not an APK. App Bundles deliver only the
target device's ABI / resources, which trims our ~253 MB APK to ~221 MB on
device.

```pwsh
flutter build appbundle --release
```

Output:

- Bundle: `build/app/outputs/bundle/release/app-release.aab`
- ProGuard / R8 mapping: `build/app/outputs/mapping/release/mapping.txt`

The mapping file is critical: without it, Play Console will not be able to
de-obfuscate stack traces from crash reports, and you will never figure out
what's broken in the field.

(If you also need a sideloadable APK for testers, run
`flutter build apk --release` — output at
`build/app/outputs/flutter-apk/app-release.apk`.)

## 5. Stage the release artifacts

Copy everything for the release into a versioned folder under `release/`
(also gitignored except for `.gitignore` itself):

```
release/0.15.2/
  app-release.aab
  app-release.apk          # optional, for direct sideload
  mapping.txt
  release-notes/
    en-US.txt
    de-DE.txt
    cs-CZ.txt
    es-ES.txt
    fr-FR.txt
    it-IT.txt
    pt-PT.txt
```

Keep this folder around — it is the canonical record of what was uploaded.
If you need to roll back or re-symbolicate a crash months later, the
`mapping.txt` for the build that's actually running on users' devices is the
only thing that matters.

### Release notes

Each `release-notes/<locale>.txt` is plain text, max ~500 chars (Play Store
limit). Mirror the CHANGELOG entry but written for users, not developers.
Cover the same set of locales the app ships in: en-US, de-DE, cs-CZ, es-ES,
fr-FR, it-IT, pt-PT. If a locale is missing on Play Console, it falls back
to en-US.

## 6. Upload to Play Console

1. Open Play Console → Internal testing (or Closed testing / Production).
2. Create a new release.
3. Upload `app-release.aab`.
4. Upload `mapping.txt` under "App bundles → ⋮ → Upload deobfuscation
   file".
5. Paste each `release-notes/<locale>.txt` into the matching language slot.
6. Review → roll out.

For first-time upload to a new track, expect a 1–2 hour review delay.

## 7. Tag and push

After the release is live (or queued for review), tag the commit:

```pwsh
git tag v0.15.2
git push origin v0.15.2
```

Tags are the easiest way to map a Play Console version code back to the
exact source commit.

## 8. Post-release

- Watch the Play Console **Vitals** tab for the first 24–48 h. ANRs and
  native crashes show up here first.
- If a crash report comes in, locate the matching `release/<version>/mapping.txt`
  and upload it via Play Console (or use `retrace` locally) to symbolicate
  the stack trace.

## iOS (placeholder)

iOS releases are not yet wired up. When that lands:

1. `flutter build ios --release`
2. Open `ios/Runner.xcworkspace` in Xcode → Product → Archive.
3. Distribute via App Store Connect.

The signing story (provisioning profiles, certificates) lives in the Apple
Developer account, not in this repo.
