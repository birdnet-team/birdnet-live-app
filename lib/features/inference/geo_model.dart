// =============================================================================
// Geo-Model — Location-based species prediction using ONNX
// =============================================================================
//
// A secondary ONNX model that predicts which species are likely to be present
// at a given geographic location and time of year.  Its output is used to
// filter or weight the audio classifier's results.
//
// ### Model interface
//
// ```
// Input:  float32 [1, 3]  — [latitude, longitude, week]
// Output: float32 [1, N]  — per-species probability vector
// ```
//
// The geo-model has its own labels file which overlaps significantly — but
// not 100% — with the audio classifier's labels.  Species are matched
// between models by scientific name.
//
// ### Labels format (tab-delimited, no header)
//
// ```
// 1044390	Orientopsaltria phaeophila	Orientopsaltria phaeophila
// ```
//
// Each line: `id<TAB>scientific_name<TAB>common_name`
//
// ### Week numbering
//
// Weeks 1–48 map to 4 weeks per calendar month:
//   - January  → weeks 1–4
//   - February → weeks 5–8
//   - …
//   - December → weeks 45–48
//
// ### Reusability
//
// This class is designed to be reusable across features (live mode, explore
// screen, survey mode).  It is a standalone service with no UI dependencies.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'ort_session_options.dart';

/// A species entry from the geo-model's own labels file.
class GeoSpecies {
  const GeoSpecies({
    required this.index,
    required this.id,
    required this.scientificName,
    required this.commonName,
  });

  /// Zero-based index in the geo-model output vector.
  final int index;

  /// ID from the labels file (the BirdNET taxonomy ID).
  final String id;

  /// Binomial scientific name.
  final String scientificName;

  /// Common name.
  final String commonName;

  @override
  String toString() => 'GeoSpecies($index: $commonName [$scientificName])';
}

/// Location-based species predictor backed by an ONNX model.
///
/// Predicts which species are expected at a given lat/lon/week and returns
/// a scored list used to filter audio classifier results.
class GeoModel {
  /// Creates an uninitialized geo-model.  Call [loadLabels] + [loadModel]
  /// before [predict].
  GeoModel();

  // ---------------------------------------------------------------------------
  // 48-Week Predictions (all species at once)
  // ---------------------------------------------------------------------------

  /// Run the geo-model for all 48 weeks at a given location and return
  /// a map of scientific name → `List<double>` (48) probabilities.
  ///
  /// This runs 48 single-sample inferences (the model input is `[1,3]`)
  /// but collects results for every species in one pass — much more
  /// efficient than calling per-species.
  Future<Map<String, List<double>>> predictAllWeeks({
    required double latitude,
    required double longitude,
  }) async {
    if (!isReady) {
      throw StateError('GeoModel not ready. Call loadLabels() + loadModel().');
    }

    // Pre-allocate result lists.
    final results = <String, List<double>>{};
    for (final label in _labels) {
      results[label.scientificName] = List<double>.filled(48, 0.0);
    }

    for (int w = 1; w <= 48; w++) {
      final scores = await predict(
        latitude: latitude,
        longitude: longitude,
        week: w,
      );
      for (final entry in scores.entries) {
        results[entry.key]?[w - 1] = entry.value;
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final OnnxRuntime _ort = OnnxRuntime();
  List<GeoSpecies> _labels = const [];
  OrtSession? _session;

  /// Configured tensor names (set from model config or defaults).
  String _inputName = 'input';
  String _outputName = 'output';

  /// Whether the geo-model is initialized and ready for predictions.
  bool get isReady => _labels.isNotEmpty && _session != null;

  /// The geo-model's own species labels.
  List<GeoSpecies> get labels => _labels;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Parse the geo-model's labels file (tab-delimited, no header).
  ///
  /// Each line: `id\tscientific_name\tcommon_name`
  ///
  /// Line `i` names output `i`, so a line that cannot be parsed is an error:
  /// skipping it would shift every later species onto the wrong score.
  void loadLabels(String labelsText) {
    final lines = labelsText.split('\n').where((l) => l.trim().isNotEmpty);
    final parsed = <GeoSpecies>[];
    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length < 2 || parts[1].trim().isEmpty) {
        throw FormatException(
          'Geo-model labels line ${parsed.length + 1} is not '
          '"id<TAB>scientific name<TAB>common name": "$line"',
        );
      }
      parsed.add(
        GeoSpecies(
          index: parsed.length,
          id: parts[0].trim(),
          scientificName: parts[1].trim(),
          commonName: parts.length >= 3 ? parts[2].trim() : parts[1].trim(),
        ),
      );
    }
    _labels = parsed;
    debugPrint('[GeoModel] loaded ${_labels.length} labels');
  }

  /// Load the geo-model ONNX file from a path on disk.
  ///
  /// [inputName] and [outputName] are the tensor names from the `geoModel`
  /// block of the model config.
  Future<void> loadModel(
    String modelPath, {
    required String inputName,
    required String outputName,
  }) async {
    _inputName = inputName;
    _outputName = outputName;

    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw FileSystemException('Geo-model file not found', modelPath);
    }

    final old = _session;
    _session = null;
    if (old != null) {
      await old.close();
    }

    _session = await _ort.createSession(
      modelPath,
      options: buildOrtSessionOptions(),
    );

    debugPrint('[GeoModel] model loaded from $modelPath');
    debugPrint('[GeoModel] input: $_inputName, output: $_outputName');
  }

  /// Release all resources.
  Future<void> dispose() async {
    final s = _session;
    _session = null;
    _labels = const [];
    if (s != null) {
      await s.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Prediction
  // ---------------------------------------------------------------------------

  /// Predict species probabilities for a geographic location and week.
  ///
  /// Returns a map of **scientific name → probability** for every species in
  /// the geo-model's label set.
  ///
  /// [latitude]  in degrees (−90 to +90).
  /// [longitude] in degrees (−180 to +180).
  /// [week]      week of the year (1–48, 4 per month).
  Future<Map<String, double>> predict({
    required double latitude,
    required double longitude,
    required int week,
  }) async {
    final session = _session;
    if (session == null || _labels.isEmpty) {
      throw StateError('GeoModel not ready. Call loadLabels() + loadModel().');
    }

    assert(week >= 1 && week <= 48, 'week must be 1–48, got $week');

    // Build input tensor: [1, 3] = [lat, lon, week]
    final inputData = Float32List.fromList([
      latitude,
      longitude,
      week.toDouble(),
    ]);
    final inputTensor = await OrtValue.fromList(inputData, [1, 3]);

    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({_inputName: inputTensor});

      final outputTensor = outputs[_outputName];
      if (outputTensor == null) {
        throw StateError(
          'Geo-model has no output named "$_outputName" '
          '(outputs: ${outputs.keys.join(', ')})',
        );
      }
      final raw = await outputTensor.asFlattenedList();
      final probabilities = raw is List<double>
          ? raw
          : raw is Float32List
          ? raw.toList()
          : raw.map((e) => (e as num).toDouble()).toList(growable: false);

      // A labels file that does not match the model would pair species with
      // the wrong scores; refuse instead of truncating to the shorter list.
      if (probabilities.length != _labels.length) {
        throw StateError(
          'Geo-model returned ${probabilities.length} scores for '
          '${_labels.length} labels',
        );
      }

      // Build the result map.
      final scores = <String, double>{};
      for (var i = 0; i < _labels.length; i++) {
        scores[_labels[i].scientificName] = probabilities[i];
      }

      return scores;
    } finally {
      await inputTensor.dispose();
      if (outputs != null) {
        for (final t in outputs.values) {
          await t.dispose();
        }
      }
    }
  }

  /// Return the subset of species whose geo-model score meets [threshold],
  /// sorted by descending probability.
  ///
  /// Returns a list of [GeoSpeciesScore] tuples.
  Future<List<GeoSpeciesScore>> expectedSpecies({
    required double latitude,
    required double longitude,
    required int week,
    double threshold = 0.03,
  }) async {
    final scores = await predict(
      latitude: latitude,
      longitude: longitude,
      week: week,
    );

    final results = <GeoSpeciesScore>[];
    for (final entry in scores.entries) {
      if (entry.value >= threshold) {
        final label = _labels.firstWhere(
          (l) => l.scientificName == entry.key,
          orElse: () => GeoSpecies(
            index: -1,
            id: '',
            scientificName: entry.key,
            commonName: entry.key,
          ),
        );
        results.add(
          GeoSpeciesScore(
            scientificName: entry.key,
            commonName: label.commonName,
            score: entry.value,
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Return geo-model scores as a map (for use with [SpeciesFilter]).
  Future<Map<String, double>> geoScoresForFilter({
    required double latitude,
    required double longitude,
    required int week,
  }) {
    return predict(latitude: latitude, longitude: longitude, week: week);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert a [DateTime] to the 1–48 week number used by the geo-model.
  ///
  /// 4 weeks per month, so January 1–7 → week 1, January 8–14 → week 2, etc.
  static int dateTimeToWeek(DateTime dt) {
    final monthBase = (dt.month - 1) * 4; // 0, 4, 8, …, 44
    final weekInMonth = ((dt.day - 1) / 7).floor().clamp(0, 3); // 0–3
    return monthBase + weekInMonth + 1; // 1–48
  }
}

/// A species with its geo-model probability score.
class GeoSpeciesScore {
  const GeoSpeciesScore({
    required this.scientificName,
    required this.commonName,
    required this.score,
  });

  final String scientificName;
  final String commonName;
  final double score;

  @override
  String toString() =>
      'GeoSpeciesScore($commonName [$scientificName]: ${score.toStringAsFixed(3)})';
}
