# ONNX Runtime Pin

`flutter_onnxruntime` is **pinned to an exact version** in `pubspec.yaml`:

```yaml
flutter_onnxruntime: 1.7.1   # NOT ^1.7.1
```

Do not widen this to a caret range without working through the re-check
procedure below and testing on a physical arm64 Android device.

## Why

v1.0.2 shipped a crash: the app died instantly when the user started a
recording. Two Play Console native traces showed a SIGSEGV deep inside
`libonnxruntime.so`, under `OrtSession.run`, with byte-identical PC offsets —
a deterministic kernel fault, not a race.

The crashing library was **ONNX Runtime 1.23.0**, confirmed by build ID:

| ONNX Runtime | arm64 `libonnxruntime.so` build ID |
| ------------ | ---------------------------------- |
| 1.22.0 | `c3b77e8b1f5d988f59094b66325830fe6e6d3af4` |
| **1.23.0** | **`34a6804242f0b38bb97f611351b9bc0630af11ae`** ← in both crash reports |

Nothing in the app changed. The native runtime was swapped underneath us:

- `pubspec.yaml` declared `flutter_onnxruntime: ^1.7.0`.
- `pubspec.lock` was gitignored, so nothing pinned the resolution.
- `flutter_onnxruntime` 1.8.1 bumped the Android native dependency from
  `onnxruntime-android:1.22.0` to `1.23.0`.
- v1.0.1 was built against 1.7.1 (ORT 1.22.0); v1.0.2 resolved 1.8.3
  (ORT 1.23.0) roughly a day later.

ORT 1.23.0 routes **fp32 GEMM through Arm KleidiAI on arm64**, which 1.22.0 did
not. Symbols present only in 1.23.0:

- `ArmKleidiAI::MlasGemmBatch`
- SME/SME2 micro-kernels (`..._sme2_mopa`, `f32p2vlx1`, `kai_lhs_pack_f32p2vlx1_f32_sme`)
- `kai_get_sme_vector_length_u32`

1.22.0 only carries KleidiAI's int4/int8 dotprod/i8mm kernels — nothing on the
fp32 path. The BirdNET classifier is fp32 conv/matmul, so with 1.23.0 every
inference enters this new code. The plugin author documented a crash in exactly
this path in the 1.8.1 changelog:

> Fix memory surge/OOM crash during inference on SME-capable ARM64 devices
> (iPhone A18+/M4+) caused by a KleidiAI convolution memory regression in ONNX
> Runtime 1.24.x (upstream microsoft/onnxruntime#29538)

They fixed it for iOS by downgrading to 1.23.0, but moved **Android up** into
1.23.0 in the same release.

There is no runtime escape hatch: ORT exposes no session-config key to disable
KleidiAI (the binary only defines `session.disable_cpu_ep_fallback`,
`session.intra_op.allow_spinning`, `session.intra_op_thread_affinities`). The
version pin is the only lever.

## Re-check procedure

**Revisit when** either of these lands:

- upstream [microsoft/onnxruntime#29538](https://github.com/microsoft/onnxruntime/issues/29538)
  is closed/fixed, or
- `flutter_onnxruntime` ships a release whose changelog moves Android to an ORT
  version **newer than 1.23.0** that includes the KleidiAI fix.

**How to re-check:**

1. Bump `pubspec.yaml` to the candidate version and `flutter pub get`.
2. Confirm which native runtime you actually got:
   ```sh
   grep onnxruntime-android \
     ~/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_onnxruntime-<ver>/android/build.gradle
   ```
3. Check whether the fp32 KleidiAI path is still compiled in. Extract the AAR
   from `~/.gradle/caches/modules-2/files-2.1/com.microsoft.onnxruntime/` and
   scan `jni/arm64-v8a/libonnxruntime.so` for `ArmKleidiAI`, `_sme2_mopa`, and
   `f32p2vlx1`. Their presence is not automatically a blocker once upstream is
   fixed — but it means step 4 is mandatory.
4. **Run a real Live session on a physical arm64 device** for several minutes.
   The crash reproduces on the first inference, so a session that survives a few
   minutes of continuous detection is a strong signal. An emulator is not a
   valid test: it may not expose the SME/SME2 CPU features that select the
   affected kernels.
5. Verify the shipped build ID matches what you tested before releasing.

If the candidate is clean, update this document with the new evidence rather
than deleting it.

## Related process fix

`pubspec.lock` is now **tracked** (see the `!pubspec.lock` negation in
`.gitignore`). This app is an application, not a library — releases must be
reproducible, and a native runtime swap must show up as a reviewable diff.
Always commit `pubspec.lock` changes deliberately, and re-read this document
when the diff touches `flutter_onnxruntime`.
