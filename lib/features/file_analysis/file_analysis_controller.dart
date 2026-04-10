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
import 'dart:isolate' as dart_isolate;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/species_filter.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';

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
  });

  final String path;
  final String fileName;
  final int fileSizeBytes;
  final Duration duration;
  final int sampleRate;
  final int totalSamples;
  final String format;

  /// Human-readable file size.
  String get fileSizeText {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

      final modelFilePath = await _ensureModelOnDisk(
        _config!.onnx.modelFile,
        _config!.version,
      );

      final labelsAssetPath =
          '${AppConstants.modelAssetsDir}/${_config!.labels.file}';
      final labelsCsv = await rootBundle.loadString(labelsAssetPath);

      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
      );

      _state = FileAnalysisState.ready;
    } catch (e, st) {
      debugPrint('[FileAnalysisController] loadModel error: $e\n$st');
      _state = FileAnalysisState.error;
      _errorMessage = e.toString();
    }

    _notifyListeners();
  }

  Future<String> _ensureModelOnDisk(String fileName, String version) async {
    final appDir = await getApplicationDocumentsDirectory();
    final versionedName = '${fileName}_v$version';
    final modelFile = File('${appDir.path}/$versionedName');

    if (!modelFile.existsSync()) {
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return modelFile.path;
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
      _ => ext.toUpperCase(),
    };

    // Decode in background isolate.
    final decoded = await dart_isolate.Isolate.run(
      () => AudioDecoder.decodeFile(path),
    );

    return AudioFileInfo(
      path: path,
      fileName: fileName,
      fileSizeBytes: fileSize,
      duration: decoded.duration,
      sampleRate: decoded.sampleRate,
      totalSamples: decoded.totalSamples,
      format: format,
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
  }) async {
    if (_state != FileAnalysisState.ready) return null;

    _state = FileAnalysisState.analyzing;
    _cancelRequested = false;
    _progress = AnalysisProgress.zero;
    _errorMessage = null;
    _notifyListeners();

    try {
      // 1. Decode the audio file in a background isolate.
      debugPrint('[FileAnalysis] decoding $filePath ...');
      final decoded = await dart_isolate.Isolate.run(
        () => AudioDecoder.decodeFile(filePath),
      );
      debugPrint('[FileAnalysis] decoded: ${decoded.totalSamples} samples, '
          '${decoded.sampleRate} Hz, ${decoded.duration}');

      // 2. Calculate windows.
      final sampleRate = decoded.sampleRate;
      final windowSamples = windowDuration * sampleRate;
      final stepSamples = (windowSamples * (1.0 - overlap)).round();
      final totalSamples = decoded.totalSamples;

      if (totalSamples < windowSamples) {
        _state = FileAnalysisState.error;
        _errorMessage = 'Audio file is shorter than the analysis window '
            '(${decoded.duration.inSeconds}s < ${windowDuration}s)';
        _notifyListeners();
        return null;
      }

      final totalWindows =
          ((totalSamples - windowSamples) / stepSamples).floor() + 1;

      debugPrint('[FileAnalysis] $totalWindows windows '
          '(window=${windowDuration}s, overlap=${(overlap * 100).round()}%, '
          'step=${stepSamples / sampleRate}s)');

      // 3. Create session.
      final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileStartTime = DateTime.now();
      final session = LiveSession(
        id: sessionId,
        startTime: fileStartTime,
        type: SessionType.fileUpload,
        settings: SessionSettings(
          windowDuration: windowDuration,
          confidenceThreshold: confidenceThreshold,
          inferenceRate: 0, // Not applicable for file analysis.
          speciesFilterMode: speciesFilterMode,
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

      // 4. Slide over windows.
      for (var w = 0; w < totalWindows; w++) {
        if (_cancelRequested) {
          debugPrint('[FileAnalysis] canceled at window $w/$totalWindows');
          break;
        }

        final startSample = w * stepSamples;
        final audioChunk = decoded.readFloat32(startSample, windowSamples);

        // Timestamp relative to audio file start.
        final windowOffsetSec = startSample / sampleRate;
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
          filtered = filtered
              .where((d) =>
                  geoModelSpeciesNames.contains(d.species.scientificName))
              .toList();
        }

        // Convert to detection records.
        for (final d in filtered) {
          final record = DetectionRecord(
            scientificName: d.species.scientificName,
            commonName: d.species.commonName,
            confidence: d.confidence,
            timestamp: windowTimestamp,
          );
          allDetections.add(record);
          speciesSet.add(d.species.scientificName);
        }

        // Update progress.
        _progress = AnalysisProgress(
          currentWindow: w + 1,
          totalWindows: totalWindows,
          detectionsFound: allDetections.length,
          speciesFound: speciesSet.length,
        );
        _notifyListeners();
      }

      // 5. Finalize session.
      session.detections.addAll(allDetections);
      // Set end time based on audio duration.
      session.endTime = fileStartTime.add(decoded.duration);
      // Store the source file path as recording path for review playback.
      session.recordingPath = filePath;

      if (_cancelRequested) {
        _state = FileAnalysisState.ready;
        _notifyListeners();
        return null;
      }

      _state = FileAnalysisState.complete;
      _notifyListeners();

      debugPrint('[FileAnalysis] complete: ${allDetections.length} detections, '
          '${speciesSet.length} species');
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
}
