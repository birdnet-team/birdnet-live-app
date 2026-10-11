// =============================================================================
// AssetPackService — Resolves ONNX model files across release flows
// =============================================================================
//
// BirdNET Live ships in two release shapes:
//
//   1. **Play Store (AAB)** — the two large `.onnx` model files (~152 MB
//      audio classifier + ~6 MB geo model) live in an *install-time*
//      Play Asset Delivery pack named `models_pack`. The pack is
//      downloaded together with the app at install time. Install-time
//      packs are **merged into the app's standard `AssetManager`
//      namespace** (`<packName>/assets/<path>` becomes `<path>` in
//      `Context.getAssets()`), and `AssetPackManager.getPackLocation()`
//      returns `null` for them by design — that API only resolves
//      fast-follow / on-demand packs. We therefore extract the model
//      bytes via the platform `AssetManager` and write them to
//      `filesDir` so ONNX Runtime can mmap a real file path.
//
//   2. **Sideload APK (GitHub release)** — there is no asset pack. The
//      `.onnx` files are bundled inside `flutter_assets` exactly as
//      before. The same native extraction reads them from the APK's
//      `flutter_assets/` directory, which is part of the same
//      `AssetManager` namespace.
//
// Both flows are fully **offline** — no network access is required at
// install or runtime.
//
// Callers should always go through [resolveModelPath] rather than
// hand-rolling the extraction logic. The resolver tries sources in
// order:
//
//   1. Native `extractAsset` (Android only) → reads from the merged
//      AssetManager namespace, first the asset pack's `models/<file>`,
//      then the sideload APK's `flutter_assets/assets/models/<file>`.
//      The copy streams through a 1 MB buffer on a worker thread and is
//      skipped when the destination already exists with the right size.
//   2. The bundled file itself (iOS, macOS, Windows, Linux) → desktop and
//      Apple builds ship `flutter_assets` as plain files inside the app
//      bundle, so the model is handed to ONNX Runtime where it already
//      is. Nothing is copied and nothing is loaded into memory.
//   3. `rootBundle.load()` extraction → the last resort (tests, an
//      unexpected bundle layout). This is the only path that holds the
//      whole model in the Dart heap, and it writes in chunks through a
//      temporary file so a crash mid-copy never leaves a truncated model
//      behind.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class AssetPackService {
  AssetPackService._();

  static const MethodChannel _channel = MethodChannel('com.birdnet/asset_pack');

  /// Bytes written per `RandomAccessFile.writeFrom` call in the fallback
  /// extraction. Each call copies only its slice into native memory, so the
  /// peak is one slice on top of the loaded asset rather than a second copy
  /// of the whole model.
  static const int _fallbackWriteChunkBytes = 4 << 20;

  /// Resolve a model file living at `assets/models/<fileName>` to an
  /// absolute on-device path suitable for passing to ONNX Runtime.
  ///
  /// [fileName] — bare file name, e.g. `BirdNET+_V3.0-...-FP16.onnx`.
  /// [version] — model version string used to suffix the extracted
  ///   copy (`<fileName>_v<version>`), so model upgrades trigger a
  ///   fresh extraction.
  static Future<String> resolveModelPath({
    required String fileName,
    required String version,
  }) async {
    final destName = '${fileName}_v$version';
    final assetKey = '${AppConstants.modelAssetsDir}/$fileName';

    // Path 1 — Android AssetManager (covers Play Store install-time
    // asset packs, since they're merged into the app namespace, and the
    // sideload APK's flutter_assets).
    if (_isAndroid) {
      for (final assetPath in [
        'models/$fileName',
        'flutter_assets/$assetKey',
      ]) {
        final extracted = await _extractNative(assetPath, destName);
        if (extracted != null) {
          debugPrint(
            '[AssetPackService] resolved $fileName via AssetManager '
            '($assetPath): $extracted',
          );
          await _removeStaleBundleExtractions(fileName);
          return extracted;
        }
      }
      debugPrint(
        '[AssetPackService] $fileName not in AssetManager — '
        'falling back to rootBundle',
      );
    } else {
      // Path 2 — the bundled file itself (iOS, macOS, Windows, Linux).
      final bundled = _bundledAssetFile(assetKey);
      if (bundled != null) {
        debugPrint('[AssetPackService] using bundled $fileName at $bundled');
        await _removeStaleBundleExtractions(fileName);
        return bundled;
      }
    }

    // Path 3 — Flutter rootBundle extraction.
    return _extractFromBundle(fileName, version);
  }

  /// Ask the Android side to stream [assetPath] into `filesDir/<destName>`.
  ///
  /// Returns null when the asset is not present or the call is unavailable,
  /// so the caller can try the next source.
  static Future<String?> _extractNative(
    String assetPath,
    String destName,
  ) async {
    try {
      final extracted = await _channel.invokeMethod<String>('extractAsset', {
        'assetPath': assetPath,
        'destName': destName,
      });
      if (extracted != null && extracted.isNotEmpty) return extracted;
    } on MissingPluginException catch (e) {
      // Old build / hot-restart against an APK without the new
      // method handler. Fall through to the bundle path.
      debugPrint('[AssetPackService] extractAsset unavailable: $e');
    } catch (e) {
      debugPrint('[AssetPackService] extractAsset error ($assetPath): $e');
    }
    return null;
  }

  /// The bundled asset as a plain file on platforms that ship
  /// `flutter_assets` unpacked, or null when it is not there.
  static String? _bundledAssetFile(String assetKey) {
    try {
      final candidate = bundledAssetPathFor(
        assetKey,
        executablePath: Platform.resolvedExecutable,
        operatingSystem: Platform.operatingSystem,
      );
      if (candidate == null) return null;
      return File(candidate).existsSync() ? candidate : null;
    } catch (e) {
      debugPrint('[AssetPackService] bundled asset lookup failed: $e');
      return null;
    }
  }

  /// Where Flutter's tooling places the asset [assetKey] (an `assets/...`
  /// key as listed in `pubspec.yaml`) relative to the running executable on
  /// platforms that ship `flutter_assets` as plain files.
  ///
  /// Returns null for platforms whose assets are not reachable as files
  /// (Android keeps them inside the APK). The result is a candidate only:
  /// the caller still checks that the file exists before using it, so an
  /// unexpected bundle layout simply falls back to extraction.
  ///
  ///   * iOS: `<Runner.app>/Frameworks/App.framework/flutter_assets/`
  ///   * macOS: `<App.app>/Contents/Frameworks/App.framework/Resources/flutter_assets/`
  ///   * Windows, Linux: `<executable dir>/data/flutter_assets/`
  @visibleForTesting
  static String? bundledAssetPathFor(
    String assetKey, {
    required String executablePath,
    required String operatingSystem,
  }) {
    if (executablePath.isEmpty) return null;
    final ctx = operatingSystem == 'windows'
        ? p.Context(style: p.Style.windows)
        : p.Context(style: p.Style.posix);
    final exeDir = ctx.dirname(executablePath);
    final keyParts = ctx.split(ctx.joinAll(p.posix.split(assetKey)));
    switch (operatingSystem) {
      case 'ios':
        return ctx.joinAll([
          exeDir,
          'Frameworks',
          'App.framework',
          'flutter_assets',
          ...keyParts,
        ]);
      case 'macos':
        return ctx.joinAll([
          ctx.dirname(exeDir),
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          ...keyParts,
        ]);
      case 'windows':
      case 'linux':
        return ctx.joinAll([exeDir, 'data', 'flutter_assets', ...keyParts]);
      default:
        return null;
    }
  }

  /// Fallback path: extract the model bytes from `rootBundle` into the
  /// app's documents directory the first time the app runs (or after a
  /// version bump).
  ///
  /// Writes through a temporary file and renames it into place, so a crash
  /// or kill mid-copy never leaves a truncated model that would pass the
  /// existence check and then fail to load on every later launch.
  static Future<String> _extractFromBundle(
    String fileName,
    String version,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final versionedName = '${fileName}_v$version';
    final modelFile = File('${appDir.path}/$versionedName');
    if (!modelFile.existsSync()) {
      debugPrint(
        '[AssetPackService] extracting $fileName v$version to '
        '${modelFile.path}',
      );
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tmpFile = File('${modelFile.path}.tmp');
      final raf = await tmpFile.open(mode: FileMode.write);
      try {
        for (
          var start = 0;
          start < bytes.length;
          start += _fallbackWriteChunkBytes
        ) {
          final end = math.min(start + _fallbackWriteChunkBytes, bytes.length);
          await raf.writeFrom(bytes, start, end);
        }
        await raf.flush();
      } finally {
        await raf.close();
      }
      if (await tmpFile.length() != bytes.length) {
        await _deleteQuietly(tmpFile);
        throw FileSystemException('Incomplete model extraction', tmpFile.path);
      }
      await tmpFile.rename(modelFile.path);
      debugPrint(
        '[AssetPackService] extraction complete '
        '(${modelFile.lengthSync()} bytes)',
      );
    }
    return modelFile.path;
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup of a partial copy.
    }
  }

  /// Drop the copies an earlier build left in the documents directory.
  ///
  /// Builds up to 1.2.0 extracted every model there through
  /// [_extractFromBundle] on iOS, Windows, and sideloaded Android. Once the
  /// model is read from the bundle or from `filesDir`, those copies are never
  /// opened again, but they are tens of megabytes each — and on iOS the
  /// documents directory is part of the device backup.
  static Future<void> _removeStaleBundleExtractions(String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      await removeStaleExtractions(appDir, fileName);
    } catch (e) {
      debugPrint('[AssetPackService] stale copy cleanup skipped: $e');
    }
  }

  /// Delete every `<fileName>_v*` file directly inside [dir]: the versioned
  /// copies [_extractFromBundle] writes, and the temporary file of one that
  /// was interrupted.
  @visibleForTesting
  static Future<void> removeStaleExtractions(
    Directory dir,
    String fileName,
  ) async {
    if (!await dir.exists()) return;
    final prefix = '${fileName}_v';
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !p.basename(entity.path).startsWith(prefix)) {
        continue;
      }
      try {
        await entity.delete();
        debugPrint('[AssetPackService] removed stale copy ${entity.path}');
      } catch (e) {
        debugPrint('[AssetPackService] could not remove ${entity.path}: $e');
      }
    }
  }

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }
}
