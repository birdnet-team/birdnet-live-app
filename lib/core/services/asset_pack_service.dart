// =============================================================================
// AssetPackService — Resolves ONNX model files across release flows
// =============================================================================
//
// BirdNET Live ships in two release shapes:
//
//   1. **Play Store (AAB)** — the two large `.onnx` model files (the
//      audio classifier and the geo model) live in an *install-time*
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
//
// Extracted copies are named `<fileName>_v<version>`, so a model update
// (new file name or new version) extracts a fresh copy. After every
// successful resolve, extracted copies that no longer belong to a model in
// `model_config.json` are deleted from both extraction locations (Android
// `filesDir` and the documents directory) — see [removeStaleExtractions].
// =============================================================================

import 'dart:async';
import 'dart:convert';
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

  /// Longest a native extraction may take before the resolver moves on to
  /// the next source. Copying the classifier is seconds on any device that
  /// can run it; minutes means the reply is not coming.
  static const Duration _nativeExtractTimeout = Duration(minutes: 3);

  /// Bytes written per `RandomAccessFile.writeFrom` call in the fallback
  /// extraction. Each call copies only its slice into native memory, so the
  /// peak is one slice on top of the loaded asset rather than a second copy
  /// of the whole model.
  static const int _fallbackWriteChunkBytes = 4 << 20;

  /// Marks an extracted model copy: `<model>.onnx_v<version>`.
  static const String _extractedMarker = '.onnx_v';

  /// Suffix of the temporary file an extraction writes before renaming it
  /// into place.
  static const String _tmpSuffix = '.tmp';

  /// Every model file this app has shipped starts with this. Part of the
  /// cleanup pattern because the documents directory is shared with user
  /// data — on Windows it is the user's own Documents folder.
  static const String _modelNamePrefix = 'BirdNET';

  /// Resolves that are still running, by extracted name. Live, Survey, and
  /// File Analysis each resolve the audio model; sharing one resolve keeps
  /// two extractions from writing the same temporary file.
  static final Map<String, Future<String>> _inFlight = {};

  /// Extracted names requested in this process. Never deleted: a session
  /// may have the file open.
  static final Set<String> _requestedNames = {};

  /// The subset of [_requestedNames] that went through the documents
  /// directory fallback.
  static final Set<String> _documentsNames = {};

  /// Extracted names of the models in `model_config.json`, once read.
  static Set<String>? _configuredNames;

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
  }) {
    final destName = '${fileName}_v$version';
    // The callback must not return the removed entry: `whenComplete` waits
    // for a returned future, and that entry is this very future.
    return _inFlight[destName] ??= _resolve(fileName, destName).whenComplete(
      () {
        _inFlight.remove(destName);
      },
    );
  }

  static Future<String> _resolve(String fileName, String destName) async {
    _requestedNames.add(destName);
    final assetKey = '${AppConstants.modelAssetsDir}/$fileName';

    // Path 1 — Android AssetManager (covers Play Store install-time
    // asset packs, since they're merged into the app namespace, and the
    // sideload APK's flutter_assets).
    if (_isAndroid) {
      try {
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
            await _removeStaleCopies(nativeDir: File(extracted).parent);
            return extracted;
          }
        }
        debugPrint(
          '[AssetPackService] $fileName not in AssetManager — '
          'falling back to rootBundle',
        );
      } on TimeoutException {
        // The native copy may still be running against the same destination.
        // A second extraction would share its temporary file and could
        // rename a truncated copy into place, so no other AssetManager source
        // is tried; the bundle fallback writes somewhere else entirely.
        debugPrint(
          '[AssetPackService] extractAsset timed out — '
          'falling back to rootBundle',
        );
      }
    } else {
      // Path 2 — the bundled file itself (iOS, macOS, Windows, Linux).
      final bundled = _bundledAssetFile(assetKey);
      if (bundled != null) {
        debugPrint('[AssetPackService] using bundled $fileName at $bundled');
        await _removeStaleCopies();
        return bundled;
      }
    }

    // Path 3 — Flutter rootBundle extraction.
    _documentsNames.add(destName);
    final extracted = await _extractFromBundle(fileName, destName);
    await _removeStaleCopies(documentsInUse: true);
    return extracted;
  }

  /// Ask the Android side to stream [assetPath] into `filesDir/<destName>`.
  ///
  /// Returns null when the asset is not present or the call is unavailable,
  /// so the caller can try the next source. A [TimeoutException] propagates:
  /// the copy may still be running, so the caller must not start another one
  /// against the same destination.
  static Future<String?> _extractNative(
    String assetPath,
    String destName,
  ) async {
    try {
      final extracted = await _channel
          .invokeMethod<String>('extractAsset', {
            'assetPath': assetPath,
            'destName': destName,
          })
          .timeout(_nativeExtractTimeout);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    } on TimeoutException {
      debugPrint('[AssetPackService] extractAsset timed out ($assetPath)');
      rethrow;
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
  /// app's documents directory as [destName] the first time the app runs
  /// (or after a model update).
  ///
  /// Writes through a temporary file and renames it into place, so a crash
  /// or kill mid-copy never leaves a truncated model that would pass the
  /// existence check and then fail to load on every later launch.
  static Future<String> _extractFromBundle(
    String fileName,
    String destName,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/$destName');
    if (!modelFile.existsSync()) {
      debugPrint(
        '[AssetPackService] extracting $fileName to ${modelFile.path}',
      );
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tmpFile = File('${modelFile.path}$_tmpSuffix');
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

  /// Delete the extracted model copies nothing uses any more.
  ///
  /// A model update changes the extracted name, and builds up to 1.2.0
  /// extracted every model into the documents directory on iOS, Windows, and
  /// sideloaded Android. Those copies are never opened again, but they are
  /// tens of megabytes each — and on iOS the documents directory is part of
  /// the device backup.
  ///
  /// [nativeDir] — where the Android side extracted to (`filesDir`); it
  ///   keeps the copies of every configured model.
  /// [documentsInUse] — whether this resolve went through the documents
  ///   directory fallback. If so the configured models are kept there too;
  ///   otherwise only the copies this process handed out from there are.
  ///
  /// Best effort: never throws into the model-loading path. When the
  /// configured names cannot be read, nothing is deleted.
  static Future<void> _removeStaleCopies({
    Directory? nativeDir,
    bool documentsInUse = false,
  }) async {
    try {
      final configured = _configuredNames ??= configuredExtractionNames(
        await rootBundle.loadString(AppConstants.modelConfigAssetPath),
      );
      final current = {...configured, ..._requestedNames};
      if (nativeDir != null) await removeStaleExtractions(nativeDir, current);
      await removeStaleExtractions(
        await getApplicationDocumentsDirectory(),
        documentsInUse ? current : _documentsNames,
      );
    } catch (e) {
      debugPrint('[AssetPackService] stale copy cleanup skipped: $e');
    }
  }

  /// The extracted names (`<fileName>_v<version>`) of the audio and geo
  /// models in the `model_config.json` text [configJson], exactly as the
  /// model loaders pass them to [resolveModelPath].
  ///
  /// Both are needed at once: the models are resolved by different
  /// controllers at different times, and cleaning up after one must not
  /// delete the other's copy.
  @visibleForTesting
  static Set<String> configuredExtractionNames(String configJson) {
    final config = json.decode(configJson) as Map<String, dynamic>;
    final audio = config['audioModel'] as Map<String, dynamic>;
    final audioFile =
        (audio['onnx'] as Map<String, dynamic>)['modelFile'] as String;
    final geo = config['geoModel'] as Map<String, dynamic>;
    final geoFile = geo['modelFile'] as String;
    return {
      '${audioFile}_v${audio['version'] as String? ?? ''}',
      '${geoFile}_v${geo['version'] as String? ?? '0'}',
    };
  }

  /// Whether [name] is a file this service extracted: a model copy
  /// `BirdNET*.onnx_v<version>`, or the `.tmp` file of an interrupted copy.
  @visibleForTesting
  static bool isExtractedModelName(String name) =>
      name.startsWith(_modelNamePrefix) &&
      _withoutTmpSuffix(name).contains(_extractedMarker);

  static String _withoutTmpSuffix(String name) => name.endsWith(_tmpSuffix)
      ? name.substring(0, name.length - _tmpSuffix.length)
      : name;

  /// Delete every extracted model copy directly inside [dir] whose name is
  /// not in [keepNames], along with the temporary file an interrupted copy
  /// of it left behind. The temporary file of a kept name stays: that copy
  /// may be running right now, and the next extraction overwrites it.
  ///
  /// Only files matching [isExtractedModelName] are considered, so sessions,
  /// recordings, and anything else stored next to the models are never
  /// touched. A file that cannot be deleted is logged and skipped.
  @visibleForTesting
  static Future<void> removeStaleExtractions(
    Directory dir,
    Set<String> keepNames,
  ) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!isExtractedModelName(name) ||
          keepNames.contains(_withoutTmpSuffix(name))) {
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
