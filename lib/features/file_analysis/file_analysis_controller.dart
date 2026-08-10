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
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/asset_pack_service.dart';
import '../inference/advanced_pooling_params.dart';
import '../inference/detection_accumulator.dart';
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/models/detection.dart';
import '../inference/species_filter.dart';
import '../inference/species_ignore_filter.dart';
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

class _PendingAnalysisWindow {
  const _PendingAnalysisWindow({
    required this.index,
    required this.startSample,
    required this.audio,
  });

  final int index;
  final int startSample;
  final Float32List audio;
}

class _DecodeChunkOutcome {
  const _DecodeChunkOutcome.success(this.chunk)
    : error = null,
      stackTrace = null;

  const _DecodeChunkOutcome.failure(this.error, this.stackTrace) : chunk = null;

  final DecodedAudio? chunk;
  final Object? error;
  final StackTrace? stackTrace;

  DecodedAudio unwrap() {
    final failure = error;
    if (failure != null) {
      Error.throwWithStackTrace(failure, stackTrace!);
    }
    return chunk!;
  }
}

// =============================================================================
// Controller
// =============================================================================

/// Orchestrates offline audio file analysis through the BirdNET pipeline.
class FileAnalysisController {
  FileAnalysisController();

  /// Number of seconds decoded at once for native compressed analysis.
  /// A chunk also includes one extra analysis window so all windows that
  /// start inside the chunk can be served without re-decoding.
  static const int _analysisChunkSeconds = 120;

  /// Upper bound for each decoded PCM16 chunk. Android keeps up to three
  /// chunks resident while two decoders run ahead of inference.
  static const int _maxDecodedChunkBytes = 16 * 1024 * 1024;

  /// Four 3-second windows gave the best measured throughput/memory balance.
  /// Keep longer-window batches within the same 12 seconds of source audio so
  /// 5- and 10-second modes do not multiply activation memory unexpectedly.
  static const int _maxInferenceBatchSize = 4;
  static const int _maxBatchedAudioSeconds = 12;

  /// Android offline analysis favors throughput over Live Mode's power needs.
  /// Five threads measured best on a Pixel 10 Pro; clamp to the actual core
  /// count so smaller devices do not oversubscribe their CPUs.
  static const int _androidOfflineInferenceThreads = 5;

  static int? get _offlineInferenceThreads =>
      Platform.isAndroid
          ? math.max(
            1,
            math.min(
              _androidOfflineInferenceThreads,
              Platform.numberOfProcessors,
            ),
          )
          : null;

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
        intraOpNumThreads: _offlineInferenceThreads,
      );

      _state = FileAnalysisState.ready;
    } catch (e, st) {
      debugPrint('[FileAnalysisController] loadModel error: $e\n$st');
      _state = FileAnalysisState.error;
      _errorMessage = null;
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
  /// [filePath] — path to the audio file.
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
    String poolingMode = 'adaptive_lme_peak',
    int maxPoolWindows = 5,
    double? poolingMaxAgeSeconds,
    AdvancedPoolingParams advancedPooling = AdvancedPoolingParams.none,
    SpeciesIgnoreSettings ignoreSettings = const SpeciesIgnoreSettings(),
    Set<String> ignoredSpeciesNames = const <String>{},
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
      late int sourceSampleRate;
      late int sourceTotalSamples;
      late Duration sourceDuration;
      late String sourceFormat;
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
        // Native compressed formats: inspect to get metadata
        final metadata = await NativeAudioDecoder.inspectFile(
          filePath,
          filePath.split('.').last.toUpperCase(),
        );
        if (metadata.sampleRate <= 0 || metadata.totalSamples <= 0) {
          _state = FileAnalysisState.error;
          _errorMessage =
              'This audio file could not be inspected safely. Try converting it to WAV or FLAC before analysis.';
          _notifyListeners();
          return null;
        }
        sourceFormat = metadata.format;
        sourceSampleRate = metadata.sampleRate;
        sourceTotalSamples = metadata.totalSamples;
        sourceDuration = metadata.duration;
      }
      debugPrint(
        '[FileAnalysis] source ready: $sourceTotalSamples samples, '
        '$sourceSampleRate Hz, $sourceDuration',
      );

      // 1b. Window sizing. All source formats are read in bounded windows or
      // chunks at source rate and resampled only for each inference window.
      final modelSampleRate = _config!.audio.sampleRate;
      final sourceWindowSamples = windowDuration * sourceSampleRate;
      final modelWindowSamples = windowDuration * modelSampleRate;
      // Offline analysis steps by a fraction of the window, so consecutive
      // windows always touch and the whole file is examined. Clamping keeps a
      // caller-supplied overlap of 1.0 (or above) from producing a zero step
      // and an unbounded window loop.
      final stepSamples = (sourceWindowSamples * (1.0 - overlap))
          .round()
          .clamp(1, sourceWindowSamples);
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
          ignoreBirds: ignoreSettings.ignoreBirds,
          ignoreMammals: ignoreSettings.ignoreMammals,
          ignoreAmphibians: ignoreSettings.ignoreAmphibians,
          ignoreInsects: ignoreSettings.ignoreInsects,
          ignoreCommonGeoScoreCutoff: ignoreSettings.commonGeoScoreCutoff,
          poolingMode: poolingMode,
          poolingWindows: maxPoolWindows,
          poolingMaxAgeSeconds: poolingMaxAgeSeconds,
          poolingAlpha: advancedPooling.alpha,
          poolingMinSupportWindows: advancedPooling.minSupportWindows,
          poolingSupportThresholdFraction:
              advancedPooling.supportThresholdFraction,
          poolingSupportThresholdFloor: advancedPooling.supportThresholdFloor,
          poolingVeryHighImmediateThreshold:
              advancedPooling.veryHighImmediateThreshold,
        ),
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

      // Parse filter mode.
      final filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoAdaptive' => SpeciesFilterMode.geoAdaptive,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      // Configure and reset temporal pooling for a fresh analysis.
      _isolate.setPoolingMode(poolingMode);
      _isolate.setMaxPoolWindows(maxPoolWindows);
      _isolate.setMaxPoolAgeSeconds(poolingMaxAgeSeconds);
      _isolate.applyAdvancedPoolingParams(advancedPooling);
      _isolate.setIgnoredSpeciesNames(ignoredSpeciesNames);
      _isolate.resetPooling();

      final allDetections = <DetectionRecord>[];
      final accumulator = DetectionAccumulator(
        sessionStart: fileStartTime,
        records: allDetections,
        // A file has a known end, and the user asked for its contents. The
        // live modes' record ceiling exists because they run indefinitely;
        // applying it here would quietly under-report a long recording.
        maxRecords: null,
      );
      final speciesSet = <String>{};

      DateTime timestampFor(int startSample) {
        // Timestamp relative to audio file start.
        final windowOffsetSec = startSample / sourceSampleRate;
        return fileStartTime.add(
          Duration(milliseconds: (windowOffsetSec * 1000).round()),
        );
      }

      void processDetections(
        _PendingAnalysisWindow window,
        List<Detection> detections, {
        required bool notify,
      }) {
        final windowTimestamp = timestampFor(window.startSample);
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

        final windowEnd = windowTimestamp.add(
          Duration(milliseconds: (windowDuration * 1000).round()),
        );
        final cycle = accumulator.processCycle(
          detections: filtered,
          windowEnd: windowEnd,
        );
        for (final change in cycle.changes) {
          if (change.isNew) speciesSet.add(change.record.scientificName);
        }

        // Update progress.
        _progress = AnalysisProgress(
          currentWindow: window.index + 1,
          totalWindows: totalWindows,
          detectionsFound: allDetections.length,
          speciesFound: speciesSet.length,
        );
        if (notify) {
          _notifyListeners();
        }
      }

      final pendingWindows = <_PendingAnalysisWindow>[];
      final inferenceBatchSize = math.min(
        _maxInferenceBatchSize,
        math.max(1, _maxBatchedAudioSeconds ~/ windowDuration),
      );

      Future<void> flushInferenceBatch() async {
        if (pendingWindows.isEmpty) return;
        if (_cancelRequested) {
          pendingWindows.clear();
          return;
        }

        final batch = List<_PendingAnalysisWindow>.of(pendingWindows);
        pendingWindows.clear();
        final detectionBatches = await _isolate.inferBatch(
          [for (final window in batch) window.audio],
          windowSeconds: windowDuration,
          sensitivity: sensitivity,
          confidenceThreshold: confidenceThreshold / 100.0,
          useTemporalPooling: poolingMode != 'off',
          timestamps: [
            for (final window in batch) timestampFor(window.startSample),
          ],
        );

        if (_cancelRequested) return;
        if (detectionBatches.length != batch.length) {
          throw StateError(
            'Inference returned ${detectionBatches.length} result batches for '
            '${batch.length} input windows',
          );
        }
        for (var index = 0; index < batch.length; index++) {
          processDetections(
            batch[index],
            detectionBatches[index],
            notify: index == batch.length - 1,
          );
        }
      }

      Future<void> enqueueWindow(
        int index,
        int startSample,
        Float32List audio,
      ) async {
        pendingWindows.add(
          _PendingAnalysisWindow(
            index: index,
            startSample: startSample,
            audio: audio,
          ),
        );
        if (pendingWindows.length >= inferenceBatchSize) {
          await flushInferenceBatch();
        }
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
            await enqueueWindow(w, startSample, audioChunk);
            return !_cancelRequested;
          },
        );
      } else {
        // WAV and native compressed formats use bounded chunks. Decode the
        // next chunk while batched model inference consumes the current one;
        // this overlaps the two dominant stages without expanding the whole
        // file into memory. Each chunk includes enough post-roll for every
        // window assigned to it.
        final maxChunkStartSpan = math.max(
          1,
          _maxDecodedChunkBytes ~/ 2 - sourceWindowSamples,
        );
        final chunkSamples = math.min(
          _analysisChunkSeconds * sourceSampleRate,
          maxChunkStartSpan,
        );

        ({int firstWindow, int endWindow, int startSample, int count})
        planChunk(int firstWindow) {
          final startSample = firstWindow * stepSamples;
          var endWindow = firstWindow + 1;
          final chunkEndSample = startSample + chunkSamples;
          while (endWindow < totalWindows &&
              endWindow * stepSamples < chunkEndSample) {
            endWindow++;
          }
          final lastWindowStart = (endWindow - 1) * stepSamples;
          final requiredSamples =
              lastWindowStart + sourceWindowSamples - startSample;
          return (
            firstWindow: firstWindow,
            endWindow: endWindow,
            startSample: startSample,
            count: math.min(requiredSamples, sourceTotalSamples - startSample),
          );
        }

        Future<_DecodeChunkOutcome> requestChunk(
          ({int firstWindow, int endWindow, int startSample, int count}) plan,
        ) async {
          try {
            debugPrint(
              '[FileAnalysis] decoding chunk at ${plan.startSample}, '
              'count ${plan.count}',
            );
            if (canDart) {
              return _DecodeChunkOutcome.success(
                await AudioDecoder.decodeRange(
                  filePath,
                  startSample: plan.startSample,
                  count: plan.count,
                ),
              );
            }

            return _DecodeChunkOutcome.success(
              await NativeAudioDecoder.decodeRange(
                filePath,
                startSample: plan.startSample,
                count: plan.count,
                allowConcurrent: Platform.isAndroid,
              ),
            );
          } catch (error, stackTrace) {
            return _DecodeChunkOutcome.failure(error, stackTrace);
          }
        }

        final plans =
            <({int firstWindow, int endWindow, int startSample, int count})>[];
        for (var firstWindow = 0; firstWindow < totalWindows;) {
          final plan = planChunk(firstWindow);
          plans.add(plan);
          firstWindow = plan.endWindow;
        }

        // Two Android MediaCodec sessions decoded the 31.5-minute benchmark
        // MP3 2.17x faster than one. Other platforms keep one decoder until
        // their native stacks have the same device coverage.
        final decodeReadAhead = !canDart && Platform.isAndroid ? 2 : 1;
        final pendingChunks =
            <
              ({
                ({int firstWindow, int endWindow, int startSample, int count})
                plan,
                Future<_DecodeChunkOutcome> outcome,
              })
            >[];
        var nextPlanIndex = 0;

        void fillDecodeQueue() {
          while (!_cancelRequested &&
              pendingChunks.length < decodeReadAhead &&
              nextPlanIndex < plans.length) {
            final nextPlan = plans[nextPlanIndex++];
            pendingChunks.add((
              plan: nextPlan,
              outcome: requestChunk(nextPlan),
            ));
          }
        }

        fillDecodeQueue();
        // A chunk that decodes short is not proof the file ended: container
        // durations are estimates and native decoders occasionally return
        // less than requested mid-file. Skip only the windows that chunk
        // cannot serve and keep going. Chunks are planned from absolute
        // sample offsets, so later chunks stay correct regardless. Give up
        // only after consecutive chunks decode nothing at all, which is what
        // a genuinely over-reported duration looks like.
        const maxEmptyChunksBeforeStop = 2;
        var consecutiveEmptyChunks = 0;
        var skippedWindows = 0;
        try {
          while (!_cancelRequested && pendingChunks.isNotEmpty) {
            final pending = pendingChunks.removeAt(0);
            final decoded = (await pending.outcome).unwrap();
            if (_cancelRequested) break;

            // Maintain read-ahead before resampling/inference so decoding can
            // overlap all CPU and native model work for this chunk.
            fillDecodeQueue();

            final plan = pending.plan;
            if (decoded.totalSamples == 0) {
              consecutiveEmptyChunks++;
              skippedWindows += plan.endWindow - plan.firstWindow;
              debugPrint(
                '[FileAnalysis] chunk at ${plan.startSample} decoded no '
                'samples (${plan.endWindow - plan.firstWindow} windows '
                'skipped)',
              );
              if (consecutiveEmptyChunks >= maxEmptyChunksBeforeStop) {
                debugPrint(
                  '[FileAnalysis] stopping after $consecutiveEmptyChunks '
                  'empty chunks; file ended before its reported duration',
                );
                break;
              }
              continue;
            }
            consecutiveEmptyChunks = 0;

            final modelChunk =
                decoded.sampleRate != modelSampleRate
                    ? decoded.resampleTo(modelSampleRate)
                    : decoded;
            for (var w = plan.firstWindow; w < plan.endWindow; w++) {
              if (_cancelRequested) {
                debugPrint(
                  '[FileAnalysis] canceled at window $w/$totalWindows',
                );
                break;
              }

              final startSample = w * stepSamples;
              final offsetInChunk = startSample - plan.startSample;
              // Decoders may return slightly fewer samples than the metadata
              // duration promises, especially for the file tail. Analyze every
              // window that still starts inside the decoded audio and let
              // readFloat32 zero-fill the remainder, as the pre-batching
              // per-window path did.
              if (offsetInChunk >= decoded.totalSamples) {
                skippedWindows += plan.endWindow - w;
                debugPrint(
                  '[FileAnalysis] chunk at ${plan.startSample} decoded '
                  '${decoded.totalSamples}/${plan.count} samples '
                  '(${plan.endWindow - w} windows skipped)',
                );
                break;
              }
              final mappedOffset =
                  (offsetInChunk * modelSampleRate / sourceSampleRate).round();
              final audioChunk = modelChunk.readFloat32(
                mappedOffset,
                modelWindowSamples,
              );
              await enqueueWindow(w, startSample, audioChunk);
            }
          }
          if (skippedWindows > 0) {
            debugPrint(
              '[FileAnalysis] $skippedWindows/$totalWindows windows were not '
              'analyzed because the audio ended early or decoded short',
            );
          }
        } finally {
          if (!canDart && pendingChunks.isNotEmpty) {
            await NativeAudioDecoder.cancelDecode();
          }
        }
      }

      await flushInferenceBatch();

      // 5. Finalize session.
      accumulator.closeAll();
      session.detections.addAll(allDetections);
      // Set end time based on audio duration.
      session.endTime = fileStartTime.add(sourceDuration);

      if (_cancelRequested) {
        _state = FileAnalysisState.ready;
        _notifyListeners();
        return null;
      }

      _progress = AnalysisProgress.zero;
      _notifyListeners();

      // Store a durable app-managed copy of the analyzed audio using the
      // user's selected recording format. Imported MP3/AAC/etc. sources are
      // transcoded in chunks to avoid full-file PCM memory spikes.
      session.recordingPath = await _persistAnalyzedAudio(
        sourcePath: filePath,
        sessionId: sessionId,
      );

      _state = FileAnalysisState.complete;
      _notifyListeners();

      debugPrint(
        '[FileAnalysis] complete: ${allDetections.length} detections, '
        '${speciesSet.length} species',
      );
      return session;
    } catch (e, st) {
      if (_cancelRequested) {
        debugPrint(
          '[FileAnalysis] analysis canceled (caught expected cancellation error: $e)',
        );
        _state = FileAnalysisState.ready;
        _notifyListeners();
        return null;
      }
      debugPrint('[FileAnalysis] error: $e\n$st');
      _state = FileAnalysisState.error;
      _errorMessage = null;
      _notifyListeners();
      return null;
    }
  }

  /// Request cancellation of the current analysis.
  void cancel() {
    _cancelRequested = true;
    NativeAudioDecoder.cancelDecode();
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

  Future<String?> _persistAnalyzedAudio({
    required String sourcePath,
    required String sessionId,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/recordings/$sessionId');
    await sessionDir.create(recursive: true);

    final ext = sourcePath.split('.').last.toLowerCase();
    final outputPath = '${sessionDir.path}/full.$ext';

    try {
      await File(sourcePath).copy(outputPath);
      return outputPath;
    } catch (e, st) {
      debugPrint('[FileAnalysis] audio persistence failed: $e\n$st');
      if (_cancelRequested) return null;
      rethrow;
    }
  }
}
