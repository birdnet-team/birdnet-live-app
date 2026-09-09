# Build Performance (Windows)

Android release builds of this app are slow on Windows in a way they are not on
macOS. This page records what was measured, what was changed, and what is left
on the table.

## What the build actually moves

Measured on this repo after a release build:

| Path | Files | Size |
| ---- | ----- | ---- |
| `build/` | 111,043 | 7.35 GB |
| `.dart_tool/` | 749 | 3.10 GB |
| `assets/` | 9,836 | 235 MB |
| `android/models_pack/` | 5 | 76.9 MB |

The shape matters more than the totals. This is a *many-small-files* workload —
over a hundred thousand file creations per build — and that is precisely the
workload where Windows is worst relative to macOS:

- **Every file write passes through Defender's real-time filter driver.**
  Real-time protection is enabled on this machine (confirmed via
  `Get-MpComputerStatus`). APFS on macOS has no equivalent per-write scan.
- **NTFS metadata operations** (create/open/close/delete) are substantially more
  expensive than APFS equivalents, and this build does an enormous number of them.
- The app is unusually asset-heavy — ~259 MB of ONNX models stored `noCompress`
  so they can be memory-mapped — so large files get copied and packaged
  repeatedly on top of the small-file churn.

## Measured results

`flutter build appbundle --release`, same machine (14 cores), timing taken from
Gradle's own `bundleRelease` figure:

| Config | Defender | `bundleRelease` | AAB |
| ------ | -------- | --------------- | --- |
| AGP 8.11.1, no perf flags | scanning | **761.7 s** | 230.7 MB |
| AGP 8.11.1, no perf flags | excluded | **466.6 s** | 230.7 MB |
| AGP 9.0.1 + parallel + caching | excluded | **315.3 s** | 229.5 MB |

**761.7 s → 315.3 s overall, a 2.4× speedup.**

The two changes were isolated deliberately: the middle row reverts the toolchain
and flags to exactly the baseline, so **Defender exclusions alone account for
−39%**. Adding AGP 9 + parallel + caching took another −32% off what remained.

Read these with three caveats:

- The 761.7 s baseline ran *without* `flutter clean`; both later rows include a
  clean. The later numbers therefore did strictly more work, so the improvement
  is understated rather than flattered.
- `org.gradle.caching=true` writes to `~/.gradle/caches/build-cache-1`, which
  `flutter clean` does **not** delete. The 315.3 s row benefits from cache
  entries populated by earlier AGP 9 builds. That is representative of everyday
  repeat builds, but a first-ever build on a fresh machine will be slower.
- `flutter clean` itself went 75 s → 14 s across the two runs, but those deleted
  different amounts (an accumulated multi-build tree vs. a single build's
  output), so that pair is not a like-for-like comparison.

## Changes made

In `android/gradle.properties`:

```properties
org.gradle.parallel=true
org.gradle.caching=true
```

The build has **23 Gradle projects** (`app` + `models_pack` + 21 Flutter plugin
modules). Without `org.gradle.parallel` they are configured and executed one at
a time, which leaves most cores idle — this machine has 14.

Both were verified with a green `flutter build appbundle --release`.

## What NOT to change

### `kotlin.incremental` must stay `false`

It looks like an easy win — it is Kotlin's own default, and it was switched off
in a commit whose message is about app icons, so it reads as accidental. It is
not. Flipping it to `true` fails the build on Windows:

```
Execution failed for task ':record_android:compileReleaseKotlin'.
> java.lang.Exception: Could not close incremental caches in
  ...\build\record_android\kotlin\compileReleaseKotlin\cacheable\caches-jvm\jvm\kotlin:
  class-fq-name-to-source.tab, source-to-classes.tab, internal-name-to-source.tab
```

Every Kotlin module failed the same way. Kotlin's incremental caches are
memory-mapped `.tab` files, and with 21 plugin modules compiling concurrently
Windows cannot release the handles. This is the same file-locking pressure that
makes the build slow in the first place.

If you hit these errors after experimenting, clear the poisoned caches:

```sh
find build -type d -name caches-jvm -prune -exec rm -rf {} +
```

## Defender exclusions — the single biggest lever (applied)

Worth more than every Gradle flag combined: **−39% on its own**, with nothing
else changed. Requires an elevated PowerShell; the exclusion list cannot even be
*read* without admin.

Currently excluded on this machine:

```
C:\Users\kahst\.gradle
C:\Users\kahst\AppData\Local\Android\Sdk
C:\Users\kahst\AppData\Local\Google\AndroidStudio2024.3
C:\Users\kahst\AppData\Local\Pub\Cache
D:\Code\birdnet-live-app
D:\flutter\flutter
```

To reproduce on another machine:

```powershell
# Run as Administrator
Add-MpPreference -ExclusionPath 'D:\Code\birdnet-live-app'
Add-MpPreference -ExclusionPath "$env:USERPROFILE\.gradle"
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Pub\Cache"
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Android\Sdk"
Add-MpPreference -ExclusionPath 'D:\flutter\flutter'
```

`build/` and `.dart_tool/` need no separate entries — they sit under the project
path. The easy ones to forget are `~\.gradle` and the Flutter SDK itself.

Verify with `Get-MpPreference` in an elevated shell, then time a build:

```sh
flutter clean && flutter build appbundle --release
```

Note the security trade-off: these paths stop being scanned in real time. That
is a normal developer-machine trade, but it is a decision, not a free win.

## Other options, not taken

- **`org.gradle.configuration-cache=true`** — potentially a large win on the
  configuration phase given 23 projects, but Flutter's Gradle plugin has a
  history of incompatibility with it. Untested here; try it in isolation.
- **Raising `-Xmx4G`** — plausible on a machine with headroom, but there was no
  evidence of heap pressure, so it would be a guess.
- **Moving the repo/caches to a different volume** — only worth investigating if
  `D:` turns out to be slower than `C:`; not measured.
