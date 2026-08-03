# Play Console Recommendations

Google Play's console raises automated "recommendations" against the uploaded
bundle. They are produced by static analysis of the *shipped bytecode*, so they
fire on code paths that exist in a dependency even when the app can never reach
them. This page records the ones we have already investigated, so nobody has to
work through the same deobfuscation twice.

Raw recommendation text is archived alongside the crash reports in
`dev/crashes/<version>/recommendations.txt`.

## Bitmap downsampling — `BitmapFactory` without `BitmapFactory.Options` (v1.0.2)

> Your app uses BitmapFactory without downsampling at: `f3.j.b`

**Status: not actionable. Unreachable in this app.**

Deobfuscated against `release/V1.0.2/mapping.txt`:

```
com.mr.flutter.plugin.filepicker.FileUtils -> f3.j
    android.net.Uri compressImage(android.net.Uri, int, android.content.Context) -> b
```

So the finding is `FileUtils.compressImage()` in the **file_picker** plugin, not
our code. In the plugin it is guarded:

```kotlin
private fun processUri(activity: Activity, uri: Uri, compressionQuality: Int): Uri {
    return if (compressionQuality > 0 && isImage(activity.applicationContext, uri)) {
        compressImage(uri, compressionQuality, activity.applicationContext)
    } else {
        uri
    }
}
```

`compressionQuality` defaults to `0` in file_picker's Dart API, and both of our
call sites leave it at the default while restricting the picker to non-image
types:

- `lib/features/file_analysis/file_analysis_screen.dart` — audio extensions
- `lib/features/survey/survey_setup_screen.dart` — `txt` / `csv`

Both conditions therefore fail and `compressImage` never runs. R8 keeps the
method because it is reachable from the plugin's method-channel dispatch, which
is why the analyzer still sees it.

**If this ever changes:** the moment we pass a non-zero `compressionQuality` or
allow image types through the picker, this stops being theoretical and the fix
belongs upstream in file_picker (it should set `BitmapFactory.Options.inSampleSize`).

## R8 — optimized resource shrinking (v1.0.2)

> Optimized resource shrinking is not enabled. Update your Android Gradle Plugin
> to version 9.0 or higher.

**Status: fixed (AGP 9 upgrade), pending device testing.**

The recommendation is correct and cannot be worked around by adding a flag. The
property that controls it is `android.r8.optimizedResourceShrinking`, and it
exists only in AGP 9.x. Verified by scanning the plugin jars directly:

| Property | AGP 8.11.1 | AGP 9.0.1 |
| -------- | ---------- | --------- |
| `android.r8.optimizedShrinking` | yes | yes |
| `android.r8.integratedResourceShrinking` | yes | yes |
| `android.r8.optimizedResourceShrinking` | **no** | **yes** |

The app already sets `minifyEnabled true` and `shrinkResources true`; this is a
further R8 mode, not a missing basic setting.

### What the upgrade involved

AGP 9 pulls two other tools with it. These are the versions now in the repo:

| Tool | Was | Now |
| ---- | --- | --- |
| Android Gradle Plugin | 8.11.1 | 9.0.1 |
| Gradle | 8.14 | 9.1.0 |
| Kotlin Gradle Plugin | 2.2.20 | 2.3.20 |

Gradle **9.1.0** is the floor, not 9.0.0 — AGP 9.0.1 rejects 9.0.0 outright:

```
Failed to apply plugin 'com.android.internal.version-check'.
> Minimum supported Gradle version is 9.1.0. Current version is 9.0.0.
```

Result: `flutter build appbundle --release` succeeds, and the bundle went from
**230.7 MB to 229.5 MB**, which is the optimized resource shrinking doing its
job (the bulk of the bundle is ONNX models, which are `noCompress`, so a 1.2 MB
drop comes entirely out of the much smaller resource section).

Notes on our specific configuration:

- **Proguard file is already correct.** AGP 9 rejects
  `getDefaultProguardFile('proguard-android.txt')` because it implies
  `-dontoptimize`. We already use `proguard-android-optimize.txt`, which is the
  replacement AGP 9 asks for.
- **`android.newDsl=false`** in `android/gradle.properties` opts out of the new
  DSL, which becomes the default in AGP 9 and is the only option in AGP 10. It
  is still honoured in 9.x, so it does not block the upgrade, but it is
  borrowed time.
- **`com.android.asset-pack`** must move in lockstep with AGP — we build a
  `models_pack` asset pack.
- Flutter 3.44 supports AGP up to 9.1 and its own project template already
  defaults to AGP 9.0.1 + Gradle 9.1.0, so this is a well-trodden path rather
  than bleeding edge.

### Still outstanding: Built-in Kotlin

The upgrade surfaced a separate warning that is *not* fixed:

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
dynamic_color, flutter_foreground_task, flutter_onnxruntime, flutter_tts
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

`android.builtInKotlin=false` is therefore load-bearing: we cannot migrate to
Built-in Kotlin until those four plugins stop applying KGP themselves. One of
them, `flutter_onnxruntime`, is deliberately pinned to an old version (see
[ONNX Runtime Pin](onnxruntime-pin.md)), so that plugin is blocked on two fronts
at once. This is a "watch the plugin changelogs" item, not something we can fix
locally.

### Ship it separately from a crash hotfix

The build is green, but a toolchain bump changes how every class is compiled and
shrunk, and optimized resource shrinking *rewrites resources* — breakage there
shows up at runtime, not at build time. A successful `bundleRelease` is not
evidence the app still works.

Do not fold this into a hotfix release. Land it on its own, and smoke-test on
real devices across a couple of Android versions first — with attention to
anything resource-driven (icons, notification channels, widget layouts, the
Quick Listen home-screen widget). Bundling an unvalidated toolchain change into
a crash fix is exactly the failure mode that produced the v1.0.2 crash.
