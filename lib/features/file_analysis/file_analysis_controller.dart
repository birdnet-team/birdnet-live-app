// =============================================================================
// File Analysis Controller — Orchestrates offline audio file analysis
// =============================================================================
//
// Processes a user-selected audio file through the BirdNET inference pipeline:
//
//   1. **Decode** — Read WAV/FLAC file into PCM samples via [AudioDecoder].
//   2. **Slide** — Iterate over the audio in overlapping windows.
//   3. **Infer** — Run each window through the ONNX model in a background
//      isolate (reuses the same [InferenceIsolate] as Live Mode).
//   4. **Accumulate** — Collect detections per window with timestamps
//      relative to the file start.
//
// ### State machine
//
// ```
//   idle ──loadModel()──▶ loading ──(success)──▶ ready
//   ready ──analyze()──▶ analyzing ──(done)──▶ complete
//                                   ──(error)──▶ error
//   complete|error ──reset()──▶ ready
// ```
//
// ### Threading
//
// Audio decoding runs via `Isolate.run()` for large files.  ONNX inference
// reuses the long-lived [InferenceIsolate].  The controller itself lives on
// the main isolate.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../../core/services/asset_pack_service.dart';
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/species_filter.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';
import '../recording/native_audio_decoder.dart';

// =============================================================================
// State
// =============================================================================

/// Lifecycle state of the file analysis pipeline.
enum FileAnalysisState {
  /// No model loaded. Call [FileAnalysisController.loadModel].
  idle,

  /// Model is being loaded from assets.
  loading,

  /// Model loaded, ready to analyze a file.
  ready,

  /// Currently analyzing an audio file.
  analyzing,

  /// Analysis completed successfully.
  complete,

  /// An error occurred.
  error,
}

/// Progress information during file analysis.
class AnalysisProgress {
  const AnalysisProgress({
    required this.currentWindow,
    required this.totalWindows,
    required this.detectionsFound,
    required this.speciesFound,
  });

  /// The window currently being processed (1-based).
  final int currentWindow;

  /// Total number of windows to process.
  final int totalWindows;

  /// Number of detections found so far.
  final int detectionsFound;

  /// Number of unique species found so far.
  final int speciesFound;

  /// Progress as a fraction (0.0–1.0).
  double get fraction => totalWindows > 0 ? currentWindow / totalWindows : 0.0;

  /// Progress as a percentage string.
  String get percentText => '${(fraction * 100).toStringAsFixed(0)}%';

  static const zero = AnalysisProgress(
    currentWindow: 0,
    totalWindows: 0,
    detectionsFound: 0,
    speciesFound: 0,
  );
}

/// Metadata about a selected audio file.
class AudioFileInfo {
  const AudioFileInfo({
    required this.path,
    required this.fileName,
    required this.fileSizeBytes,
    required this.duration,
    required this.sampleRate,
    required this.totalSamples,
    required this.format,
    int? estimatedDecodedBytes,
  }) : estimatedDecodedBytes = estimatedDecodedBytes ?? totalSamples * 2;

  final String path;
  final String fileName;
  final int fileSizeBytes;
  final Duration duration;
  final int sampleRate;
  final int totalSamples;
  final String format;
  final int estimatedDecodedBytes;

  /// True when analysis/review may need noticeable memory for decoded PCM.
  bool get hasLargeDecodedFootprint =>
      estimatedDecodedBytes >= 128 * 1024 * 1024;

  /// True when the file is large enough that older devices may struggle.
  bool get hasVeryLargeDecodedFootprint =>
      estimatedDecodedBytes >= 256 * 1024 * 1024;

  /// Human-readable file size.
  String get fileSizeText {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Human-readable decoded PCM estimate.
  String get decodedSizeText {
    if (estimatedDecodedBytes < 1024 * 1024) {
      return '${(estimatedDecodedBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(estimatedDecodedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Human-readable duration.
  String get durationText {
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    return '${min}m ${sec}s';
  }
}

// =============================================================================
// Controller
// =============================================================================

/// Orchestrates offline audio file analysis through the BirdNET pipeline.
class FileAnalysisController {
  FileAnalysisController();

  /// Native compressed formats still decode through a full platform PCM
  /// buffer before analysis. Keep that path bounded until native range/
  /// streaming decode exists; WAV/FLAC use the Dart range/window paths
  /// below and can handle much larger decoded footprints safely.
  static const int _maxNativeDecodeBytes = 256 * 1024 * 1024;

  /// If a native compressed file's duration is unknown, decoded PCM size
  /// cannot be estimated. In that case, treat large source files as unsafe
  /// for the current full-decode path.
  static const int _maxNativeUnknownDurationBytes = 64 * 1024 * 1024;

  // ── Internal state ────────────────────────────────────────────────────

  final InferenceIsolate _isolate = InferenceIsolate();
  ModelConfig? _config;
  FileAnalysisState _state = FileAnalysisState.idle;
  String? _errorMessage;
  AnalysisProgress _progress = AnalysisProgress.zero;
  bool _cancelRequested = false;

  // ── Getters ───────────────────────────────────────────────────────────

  FileAnalysisState get state => _state;
  String? get errorMessage => _errorMessage;
  ModelConfig? get config => _config;
  AnalysisProgress get progress => _progress;

  // ── Callbacks ─────────────────────────────────────────────────────────

  /// Called whenever state or progress changes.
  void Function()? onStateChanged;

  // ── Model loading ─────────────────────────────────────────────────────

  /// Load the ONNX model from Flutter assets.
  Future<void> loadModel() async {
    if (_state == FileAnalysisState.loading ||
        _state == FileAnalysisState.ready) {
      return;
    }

    _state = FileAnalysisState.loading;
    _errorMessage = null;
    _notifyListeners();

    try {
      final configJson = await rootBundle.loadString(
        AppConstants.modelConfigAssetPath,
      );
      final fullConfig = json.decode(configJson) as Map<String, dynamic>;
      _config = ModelConfig.fromJson(
        fullConfig['audioModel'] as Map<String, dynamic>,
      );

      // Resolve via install-time asset pack (Play Store AAB) or fall
      // back to extracting from rootBundle (sideload APK).
      final modelFilePath = await AssetPackService.resolveModelPath(
        fileName: _config!.onnx.modelFile,
        version: _config!.version,
      );

      final labelsAssetPath =
          '${AppConstants.modelAssetsDir}/${_config!.labels.file}';
      final labelsCsv = await rootBundle.loadString(labelsAssetPath);

      final blacklistFile = _config!.scoreBlacklistFile;
      final scoreBlacklistJson =
          blacklistFile == null
              ? null
              : await rootBundle.loadString(
                '${AppConstants.modelAssetsDir}/$blacklistFile',
              );

      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
        scoreBlacklistJson: scoreBlacklistJson,
      );

      _state = FileAnalysisState.ready;
    } catch (e, st) {
      debugPrint('[FileAnalysisController] loadModel error: $e\n$st');
      _state = FileAnalysisState.error;
      _errorMessage = e.toString();
    }

    _notifyListeners();
  }

  // ── File inspection ───────────────────────────────────────────────────

  /// Decode the audio file and return metadata without running inference.
  ///
  /// Runs decoding in a background isolate for large files.
  Future<AudioFileInfo> inspectFile(String path) async {
    final file = File(path);
    final fileSize = await file.length();
    final fileName = path.split(Platform.pathSeparator).last;

    // Detect format from extension.
    final ext = fileName.split('.').last.toLowerCase();
    final format = switch (ext) {
      'wav' || 'wave' => 'WAV',
      'flac' => 'FLAC',
      'mp3' => 'MP3',
      'ogg' || 'oga' => 'OGG',
      'm4a' || 'aac' || 'mp4' => 'AAC',
      'opus' => 'OPUS',
      'wma' => 'WMA',
      'amr' => 'AMR',
      _ => ext.toUpperCase(),
    };

    // Inspect metadata without decoding full PCM. Long compressed files can
    // expand to hundreds of megabytes once decoded, so the file picker step
    // must stay lightweight.
    final canDart = await AudioDecoder.canDecodeDart(path);
    final metadata =
        canDart
            ? await AudioDecoder.inspectFile(path)
            : await NativeAudioDecoder.inspectFile(path, format);

    return AudioFileInfo(
      path: path,
      fileName: fileName,
      fileSizeBytes: fileSize,
      duration: metadata.duration,
      sampleRate: metadata.sampleRate,
      totalSamples: metadata.totalSamples,
      format: format,
      estimatedDecodedBytes: metadata.decodedPcmBytes,
    );
  }

  // ── Analysis ──────────────────────────────────────────────────────────

  /// Analyze an audio file and return a completed session.
  ///
  /// [filePath] — path to the audio file (WAV or FLAC).
  /// [windowDuration] — analysis window in seconds.
  /// [overlap] — window overlap as a fraction (0.0 = no overlap, 0.5 = 50%).
  /// [sensitivity] — sensitivity scaling factor.
  /// [confidenceThreshold] — minimum confidence (0–100 scale).
  /// [speciesFilterMode] — species filter setting.
  /// [geoScores] — optional geo-model predictions for species filtering.
  /// [geoThreshold] — minimum geo score for the geoExclude filter.
  /// [geoModelSpeciesNames] — restrict to species known by both models.
  /// [latitude] — recording location latitude (optional).
  /// [longitude] — recording location longitude (optional).
  /// [locationName] — reverse-geocoded location name (optional).
  Future<LiveSession?> analyze({
    required String filePath,
    required int windowDuration,
    double overlap = 0.0,
    double sensitivity = 1.0,
    required int confidenceThreshold,
    required String speciesFilterMode,
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? recordingDate,
  }) async {
    if (_state != FileAnalysisState.ready) return null;

    _state = FileAnalysisState.analyzing;
    _cancelRequested = false;
    _progress = AnalysisProgress.zero;
    _errorMessage = null;
    _notifyListeners();

    try {
      // 1. Inspect/decode the audio source.
      final canDart = await AudioDecoder.canDecodeDart(filePath);
      DecodedAudio? fullAudio;
      late int sourceSampleRate;
      late int sourceTotalSamples;
      late Duration sourceDuration;
      String? sourceFormat;
      if (canDart) {
        final metadata = await AudioDecoder.inspectFile(filePath);
        sourceFormat = metadata.format;
        sourceSampleRate = metadata.sampleRate;
        sourceTotalSamples = metadata.totalSamples;
        sourceDuration = metadata.duration;
        debugPrint(
          '[FileAnalysis] inspected: $sourceTotalSamples samples, '
          '$sourceSampleRate Hz, $sourceDuration',
        );
      } else {
        // Native compressed formats still need a full decode today, but the
        // file picker metadata path above no longer pays this cost twice.
        final metadata = await NativeAudioDecoder.inspectFile(
          filePath,
          filePath.split('.').last.toUpperCase(),
        );
        final fileSize = await File(filePath).length();
        if (metadata.sampleRate <= 0 || metadata.totalSamples < 0) {
          _state = FileAnalysisState.error;
          _errorMessage =
              'This audio file could not be inspected safely. Try converting it to WAV or FLAC before analysis.';
          _notifyListeners();
          return null;
        }
        if (metadata.decodedPcmBytes >= _maxNativeDecodeBytes ||
            (metadata.totalSamples == 0 &&
                fileSize >= _maxNativeUnknownDurationBytes)) {
          _state = FileAnalysisState.error;
          final estimate =
              metadata.totalSamples > 0
                  ? ' Its decoded audio would use about '
                      '${_formatBytes(metadata.decodedPcmBytes)} of memory.'
                  : ' The platform could not report its decoded duration, and the source file is ${_formatBytes(fileSize)}.';
          _errorMessage =
              'This compressed file is too large to analyze safely on this device.$estimate '
              'Use WAV or FLAC for long recordings so BirdNET Live can analyze the file in chunks.';
          _notifyListeners();
          return null;
        }
        debugPrint('[FileAnalysis] decoding $filePath ...');
        final decoded = await NativeAudioDecoder.decodeFile(filePath);
        final modelSampleRate = _config!.audio.sampleRate;
        fullAudio =
            decoded.sampleRate != modelSampleRate
                ? decoded.resampleTo(modelSampleRate)
                : decoded;
        sourceSampleRate = fullAudio.sampleRate;
        sourceTotalSamples = fullAudio.totalSamples;
        sourceDuration = fullAudio.duration;
        if (fullAudio != decoded) {
          debugPrint(
            '[FileAnalysis] resampled '
            '${decoded.sampleRate} Hz → $modelSampleRate Hz '
            '(${fullAudio.totalSamples} samples)',
          );
        }
      }
      debugPrint(
        '[FileAnalysis] source ready: $sourceTotalSamples samples, '
        '$sourceSampleRate Hz, $sourceDuration',
      );

      // 1b. Window sizing. WAV/FLAC windows are read at source rate and
      // resampled per-window if needed; native compressed files are already
      // fully decoded/resampled above.
      final modelSampleRate = _config!.audio.sampleRate;
      final sourceWindowSamples = windowDuration * sourceSampleRate;
      final modelWindowSamples = windowDuration * modelSampleRate;
      final stepSamples = (sourceWindowSamples * (1.0 - overlap)).round();
      final totalSamples = sourceTotalSamples;

      if (sourceTotalSamples == 0) {
        _state = FileAnalysisState.error;
        _errorMessage = 'Audio file duration could not be determined';
        _notifyListeners();
        return null;
      }

      if (totalSamples < sourceWindowSamples) {
        _state = FileAnalysisState.error;
        _errorMessage =
            'Audio file is shorter than the analysis window '
            '(${sourceDuration.inSeconds}s < ${windowDuration}s)';
        _notifyListeners();
        return null;
      }

      final totalWindows =
          ((totalSamples - sourceWindowSamples) / stepSamples).floor() + 1;

      debugPrint(
        '[FileAnalysis] $totalWindows windows '
        '(window=${windowDuration}s, overlap=${(overlap * 100).round()}%, '
        'step=${stepSamples / sourceSampleRate}s)',
      );

      // 3. Create session.
      final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileStartTime = recordingDate ?? DateTime.now();
      final session = LiveSession(
        id: sessionId,
        startTime: fileStartTime,
        type: SessionType.fileUpload,
        settings: SessionSettings(
          windowDuration: windowDuration,
          confidenceThreshold: confidenceThreshold,
          inferenceRate: 0, // Not applicable for file analysis.
          speciesFilterMode: speciesFilterMode,
          sensitivity: sensitivity,
        ),
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

      // Parse filter mode.
      final filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      // Reset temporal pooling for a fresh analysis.
      _isolate.resetPooling();

      final allDetections = <DetectionRecord>[];
      final speciesSet = <String>{};
      // Active species → index into [allDetections] of the in-progress
      // record. While a species stays above threshold across consecutive
      // windows, its single record's [endTimestamp] is extended; once it
      // dips below (or analysis ends), the record is left closed.
      final activeIndex = <String, int>{};
      // Names that were above threshold in the previous window. Used to
      // detect species that dropped out so we stop extending their record.
      var previousWindowNames = <String>{};

      Future<void> processWindow(
        int w,
        int startSample,
        Float32List audioChunk,
      ) async {
        // Timestamp relative to audio file start.
        final windowOffsetSec = startSample / sourceSampleRate;
        final windowTimestamp = fileStartTime.add(
          Duration(milliseconds: (windowOffsetSec * 1000).round()),
        );

        // Run inference.
        final detections = await _isolate.infer(
          audioChunk,
          windowSeconds: windowDuration,
          sensitivity: sensitivity,
          confidenceThreshold: confidenceThreshold / 100.0,
          useTemporalPooling: false,
        );

        // Apply species filter.
        var filtered = SpeciesFilter.apply(
          detections: detections,
          mode: filterMode,
          geoScores: geoScores,
          geoThreshold: geoThreshold,
          confidenceThreshold: confidenceThreshold / 100.0,
        );

        // Restrict to geo-model species intersection.
        if (geoModelSpeciesNames != null) {
          filtered =
              filtered
                  .where(
                    (d) =>
                        geoModelSpeciesNames.contains(d.species.scientificName),
                  )
                  .toList();
        }

        // Convert to detection records, merging consecutive windows of
        // the same species into a single record whose [endTimestamp]
        // grows as long as the species stays above threshold.
        final windowEnd = windowTimestamp.add(
          Duration(milliseconds: (windowDuration * 1000).round()),
        );
        final currentNames = <String>{
          for (final d in filtered) d.species.scientificName,
        };
        // Species that were active last window but not this one — stop
        // extending them; their last [endTimestamp] is already correct.
        for (final name in previousWindowNames.difference(currentNames)) {
          activeIndex.remove(name);
        }
        for (final d in filtered) {
          final name = d.species.scientificName;
          final existingIdx = activeIndex[name];
          if (existingIdx == null) {
            // New continuous detection for this species.
            final record = DetectionRecord(
              scientificName: name,
              commonName: d.species.commonName,
              confidence: d.confidence,
              timestamp: windowTimestamp,
              endTimestamp: windowEnd,
            );
            allDetections.add(record);
            activeIndex[name] = allDetections.length - 1;
            speciesSet.add(name);
          } else {
            // Continuation — extend the existing record's window and
            // bump confidence to the highest value seen so far.
            final existing = allDetections[existingIdx];
            allDetections[existingIdx] = DetectionRecord(
              scientificName: existing.scientificName,
              commonName: existing.commonName,
              confidence: math.max(existing.confidence, d.confidence),
              timestamp: existing.timestamp,
              endTimestamp: windowEnd,
              audioClipPath: existing.audioClipPath,
              source: existing.source,
              latitude: existing.latitude,
              longitude: existing.longitude,
            );
          }
        }
        previousWindowNames = currentNames;

        // Update progress.
        _progress = AnalysisProgress(
          currentWindow: w + 1,
          totalWindows: totalWindows,
          detectionsFound: allDetections.length,
          speciesFound: speciesSet.length,
        );
        _notifyListeners();
      }

      // 4. Slide over windows. FLAC is decoded sequentially so long files do
      // not restart from the beginning for every analysis window.
      if (canDart && sourceFormat == 'FLAC') {
        await AudioDecoder.decodeFlacWindows(
          filePath,
          windowSamples: sourceWindowSamples,
          stepSamples: stepSamples,
          maxWindows: totalWindows,
          onWindow: (w, startSample, sourceChunk) async {
            if (_cancelRequested) {
              debugPrint('[FileAnalysis] canceled at window $w/$totalWindows');
              return false;
            }
            final modelChunk =
                sourceChunk.sampleRate != modelSampleRate
                    ? sourceChunk.resampleTo(modelSampleRate)
                    : sourceChunk;
            final audioChunk = modelChunk.readFloat32(0, modelWindowSamples);
            await processWindow(w, startSample, audioChunk);
            return !_cancelRequested;
          },
        );
      } else {
        for (var w = 0; w < totalWindows; w++) {
          if (_cancelRequested) {
            debugPrint('[FileAnalysis] canceled at window $w/$totalWindows');
            break;
          }

          final startSample = w * stepSamples;
          final Float32List audioChunk;
          if (canDart) {
            final sourceChunk = await AudioDecoder.decodeRange(
              filePath,
              startSample: startSample,
              count: sourceWindowSamples,
            );
            final modelChunk =
                sourceChunk.sampleRate != modelSampleRate
                    ? sourceChunk.resampleTo(modelSampleRate)
                    : sourceChunk;
            audioChunk = modelChunk.readFloat32(0, modelWindowSamples);
          } else {
            audioChunk = fullAudio!.readFloat32(
              startSample,
              sourceWindowSamples,
            );
          }
          await processWindow(w, startSample, audioChunk);
        }
      }

      // 5. Finalize session.
      session.detections.addAll(allDetections);
      // Set end time based on audio duration.
      session.endTime = fileStartTime.add(sourceDuration);
      // Store the source file path as recording path for review playback.
      session.recordingPath = filePath;

      if (_cancelRequested) {
        _state = FileAnalysisState.ready;
        _notifyListeners();
        return null;
      }

      _state = FileAnalysisState.complete;
      _notifyListeners();

      debugPrint(
        '[FileAnalysis] complete: ${allDetections.length} detections, '
        '${speciesSet.length} species',
      );
      return session;
    } catch (e, st) {
      debugPrint('[FileAnalysis] error: $e\n$st');
      _state = FileAnalysisState.error;
      _errorMessage = e.toString();
      _notifyListeners();
      return null;
    }
  }

  /// Request cancellation of the current analysis.
  void cancel() {
    _cancelRequested = true;
  }

  /// Reset to ready state (after completion or error).
  void reset() {
    if (_state == FileAnalysisState.complete ||
        _state == FileAnalysisState.error) {
      _state = FileAnalysisState.ready;
      _progress = AnalysisProgress.zero;
      _errorMessage = null;
      _notifyListeners();
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _cancelRequested = true;
    await _isolate.stop();
  }

  void _notifyListeners() {
    onStateChanged?.call();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
