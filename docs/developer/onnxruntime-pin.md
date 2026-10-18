# ONNX Runtime Pin

`flutter_onnxruntime` is **pinned to an exact version** in `pubspec.yaml`:

```yaml
flutter_onnxruntime: 1.9.0   # NOT ^1.9.0
```

Do not widen this to a caret range, and do not bump it, without working through
the re-check procedure below and testing on a physical arm64 Android device.

Every ONNX session the app opens also carries the session config entry
`mlas.disable_kleidiai = "1"`, set in one place:
`lib/features/inference/ort_session_options.dart`. Both models (audio
classifier and geo-model) go through that helper. Keep it that way.

## Why the pin exists

v1.0.2 shipped a crash: the app died instantly when the user started a
recording. Two Play Console native traces showed a SIGSEGV deep inside
`libonnxruntime.so`, under `OrtSession.run`, with byte-identical PC offsets —
a deterministic kernel fault, not a race.

The crashing library was **ONNX Runtime 1.23.0**, confirmed by build ID:

| ONNX Runtime | arm64 `libonnxruntime.so` build ID |
| ------------ | ---------------------------------- |
| 1.22.0 | `c3b77e8b1f5d988f59094b66325830fe6e6d3af4` |
| **1.23.0** | **`34a6804242f0b38bb97f611351b9bc0630af11ae`** ← in both crash reports |
| 1.28.0 | `b178f5c22304a25ff481e608260312842627e868` (current) |

Nothing in the app had changed. The native runtime was swapped underneath us:

- `pubspec.yaml` declared `flutter_onnxruntime: ^1.7.0`.
- `pubspec.lock` was gitignored, so nothing pinned the resolution.
- `flutter_onnxruntime` 1.8.1 bumped the Android native dependency from
  `onnxruntime-android:1.22.0` to `1.23.0`.
- v1.0.1 was built against 1.7.1 (ORT 1.22.0); v1.0.2 resolved 1.8.3
  (ORT 1.23.0) roughly a day later.

ORT 1.23.0 was the first release to route **fp32 GEMM and convolution through
Arm KleidiAI on arm64**. The override is installed at runtime when the CPU
reports SME (`MLAS_CPUIDINFO::HasArm_SME()` in `mlas/lib/platform.cpp`), so
only SME-capable phones ever entered the new code; everything else kept the
NEON MLAS path that 1.22.0 used everywhere. The BirdNET classifier is fp32
conv/matmul, so on an SME device every inference went through the new kernels.
Symbols present only from 1.23.0 on:

- `ArmKleidiAI::MlasGemmBatch`
- SME/SME2 micro-kernels (`..._sme2_mopa`, `f32p2vlx1`, `kai_lhs_pack_f32p2vlx1_f32_sme`)

The same kernel family kept producing field reports after 1.23.0:

- memory retention on SME hardware — static `thread_local` packed-operand
  buffers that grow and never shrink; the convolution half was fixed in 1.27.1
  (microsoft/onnxruntime#28571), the MatMul half was still open against 1.28.0
  when microsoft/onnxruntime#29538 was reopened on 2026-09-12;
- wrong results from the batch-1 convolution route on arm64 in 1.27.0, fixed in
  1.28.0 (reported via sherpa-onnx and livekit-wakeword).

ORT 1.23.0 had no way to turn this off, so at the time the version pin (1.7.1,
ORT 1.22.0) was the only lever.

## Why 1.9.0 is safe: the KleidiAI switch

ONNX Runtime 1.28 added the session option
`kOrtSessionOptionsMlasDisableKleidiAi = "mlas.disable_kleidiai"`. It is a
first-class, documented option, not a debugging hook:

- `onnxruntime/core/providers/cpu/mlas_backend_kernel_selector_config_utils.h`
  reads it into `MLAS_BACKEND_KERNEL_SELECTOR_CONFIG.use_kleidiai`;
- `Conv`, `FusedConv`, `MatMul`/`Gemm` (`providers/cpu/nn/conv.cc`,
  `providers/cpu/math/matmul.cc`) pass that config into every MLAS call, and
  `mlas/lib/sgemm.cpp` / `mlas/lib/convolve.cpp` only take the KleidiAI
  override when `use_kleidiai` is true;
- the NHWC graph optimizer (`optimizer/nhwc_transformer.cc`) skips the
  KleidiAI-only `NhwcFusedConv` rewrite when it is false.

With the entry set, an SME phone runs the exact same NEON MLAS kernels as every
other arm64 device, i.e. the path ORT 1.22.0 used and the one the app has been
shipping since 1.0.3. `flutter_onnxruntime` 1.9.0 is the first plugin release
that both exposes session config entries (`OrtSessionOptions.sessionConfigs`,
forwarded verbatim to `SessionOptions.addConfigEntry` on Android, iOS, macOS,
Windows, Linux and web) and bundles an ORT that understands the key. Runtimes
that predate the key accept and ignore it.

Verified in the shipped Android binary (`onnxruntime-android-1.28.0.aar`,
`jni/arm64-v8a/libonnxruntime.so`): the string `mlas.disable_kleidiai` is
present, the KleidiAI symbols are still compiled in (so the switch, not the
build, is what keeps them out), and the ELF `LOAD` segments are 16 KB aligned.

## Validation log

| Check | Result |
| ----- | ------ |
| Dart API diff 1.7.1 → 1.9.0 | additive only (`sessionConfigs`, self-healing asset extraction); no call-site changes needed |
| `flutter analyze`, `flutter test` | clean |
| `integration_test/model_output_test.dart` on Pixel 10 Pro (Tensor G5, Android 17, arm64, no SME), 2026-10-11 | 5/5 passed: detections match the Python reference for every fixture window, batched = single-window output, no crash |
| Live Mode session on the same Pixel 10 Pro (debug build), 2026-10-11 | 8 min 10 s, 487 inference runs, 9 species / 28 detections, geo-model loaded with a fix, session finalized into Session Review; RSS sampled every minute stayed within 848–867 MB with no upward trend; no `Fatal signal`/ANR in logcat |
| Release APK (R8, built-in Kotlin), 2026-10-11 | packaged `libonnxruntime.so` build ID `b178f5c22304a25ff481e608260312842627e868` = the inspected 1.28.0 AAR; `mlas.disable_kleidiai` present; `ai.onnxruntime.OrtSession$SessionOptions` kept by R8 |

A Pixel 10 Pro has no SME, so on that device the KleidiAI override is never
installed regardless of the switch. That is the point: it exercises exactly the
NEON path that the switch forces on SME devices too. The switch itself is
verified from the 1.28.0 sources above and from the key string in the binary,
not from a device that cannot reach the kernels.

## Windows: the runtime version is pinned in `windows/CMakeLists.txt`

On Windows the plugin downloads a prebuilt ONNX Runtime at CMake configure time
and only applies its own default when `ONNXRUNTIME_VERSION` is empty.
`flutter_onnxruntime` ≤ 1.8.x stored that variable in the CMake **cache**
(`ONNXRUNTIME_VERSION:STRING=1.22.0` in `build/windows/x64/CMakeCache.txt`), so
after the 1.9.0 bump an incremental build silently kept linking 1.22.0 — the
shipped `onnxruntime.dll` still reported `1.22.20250508`. The app therefore
sets `ONNXRUNTIME_VERSION` itself in `windows/CMakeLists.txt`, before the
generated plugin rules are included; a normal variable takes precedence over
any cached value, so the pin holds on dirty and clean build trees alike. When
bumping the plugin, update that line to the default the new plugin version
ships (`windows/CMakeLists.txt` in the plugin's pub cache directory) and confirm
the configure output says `ONNX Runtime version set to: <expected>`. Windows x64
has no KleidiAI, so the switch is inert there; the version still matters for
parity with Android.

## Re-check procedure

**Revisit when** any of these lands:

- `flutter_onnxruntime` ships a release that moves Android to a newer ORT;
- [microsoft/onnxruntime#29538](https://github.com/microsoft/onnxruntime/issues/29538)
  is closed with the MatMul/SGEMM `thread_local` retention fixed (the
  convolution half landed in 1.27.1). Only then consider removing
  `mlas.disable_kleidiai`, and not without a device that reports `sme` in
  `/proc/cpuinfo` and a multi-hour soak that watches RSS, because that bug is
  about memory that only grows in long-lived processes — which is what a
  Survey or ARU session is;
- [flutter/flutter#189770](https://github.com/flutter/flutter/issues/189770)
  ships the patched KGP regex, or the plugin drops its conditional guard: the
  remaining `plugins that apply KGP: flutter_onnxruntime` warning line then
  disappears without any change on our side.

**How to re-check:**

1. Bump `pubspec.yaml` to the candidate version and `flutter pub get`.
2. Confirm which native runtime you actually got:
   ```sh
   grep onnxruntime-android \
     ~/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_onnxruntime-<ver>/android/build.gradle
   ```
3. Confirm the switch still exists in that runtime. Download the AAR from
   Maven Central
   (`https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/<ver>/`),
   unzip it, and check `jni/arm64-v8a/libonnxruntime.so` and
   `jni/x86_64/libonnxruntime.so` for the string `mlas.disable_kleidiai`. If the key is gone, read that release's
   `onnxruntime_session_options_config_keys.h` before going any further.
4. Push the fixtures and run the model output integration test on a physical
   arm64 device — it compares detections against the Python reference, so it
   catches numerical drift as well as crashes:
   ```sh
   adb push assets/test_fixtures /data/local/tmp/test_fixtures
   flutter test integration_test/model_output_test.dart -d <device_id>
   ```
   Then run a real Live session for several minutes. An emulator is not a
   valid substitute for the arm64 build. The bundle also ships an x86_64
   build for Intel/AMD Chromebooks, which has no KleidiAI path but is its
   own binary: run the same integration test once on an x86_64 emulator so
   that split is covered too.
5. Build the release APK and verify the packaged `libonnxruntime.so` build ID
   matches the AAR you inspected
   (`llvm-readelf -n lib/<abi>/libonnxruntime.so` from the Android NDK, for
   both `arm64-v8a` and `x86_64`).

If the candidate is clean, update this document with the new evidence rather
than deleting it.

## Related process fix

`pubspec.lock` is **tracked** (see the `!pubspec.lock` negation in
`.gitignore`). This app is an application, not a library — releases must be
reproducible, and a native runtime swap must show up as a reviewable diff.
Always commit `pubspec.lock` changes deliberately, and re-read this document
when the diff touches `flutter_onnxruntime`.

On iOS the runtime arrives through Swift Package Manager, so the same applies
to the two `xcshareddata/swiftpm/Package.resolved` files under
`ios/Runner.xcworkspace` and `ios/Runner.xcodeproj/project.xcworkspace`. They
pin the exact `onnxruntime-swift-package-manager` revision the plugin's
`exact:` version resolved to; Xcode rewrites them on every build, so a change
there is a runtime change to review, not noise.
