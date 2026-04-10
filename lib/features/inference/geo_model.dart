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
import 'package:onnxruntime/onnxruntime.dart';

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

  /// Sparse internal ID (from the labels file).
  final int id;

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
  /// a map of scientific name → List<double>(48) probabilities.
  ///
  /// This runs 48 single-sample inferences (the model input is [1,3])
  /// but collects results for every species in one pass — much more
  /// efficient than calling per-species.
  Map<String, List<double>> predictAllWeeks({
    required double latitude,
    required double longitude,
  }) {
    if (!isReady) {
      throw StateError('GeoModel not ready. Call loadLabels() + loadModel().');
    }

    // Pre-allocate result lists.
    final results = <String, List<double>>{};
    for (final label in _labels) {
      results[label.scientificName] = List<double>.filled(48, 0.0);
    }

    for (int w = 1; w <= 48; w++) {
      final scores = predict(
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

  List<GeoSpecies> _labels = const [];
  OrtSession? _session;
  bool _envInitialized = false;

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
  void loadLabels(String labelsText) {
    final lines = labelsText.split('\n').where((l) => l.trim().isNotEmpty);
    final parsed = <GeoSpecies>[];
    var idx = 0;
    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length >= 2) {
        parsed.add(GeoSpecies(
          index: idx,
          id: int.tryParse(parts[0].trim()) ?? 0,
          scientificName: parts[1].trim(),
          commonName: parts.length >= 3 ? parts[2].trim() : parts[1].trim(),
        ));
        idx++;
      }
    }
    _labels = parsed;
    debugPrint('[GeoModel] loaded ${_labels.length} labels');
  }

  /// Load the geo-model ONNX file from a path on disk.
  ///
  /// [inputName] and [outputName] configure the tensor names.
  Future<void> loadModel(
    String modelPath, {
    String inputName = 'input',
    String outputName = 'output',
  }) async {
    _inputName = inputName;
    _outputName = outputName;

    if (!_envInitialized) {
      OrtEnv.instance.init();
      _envInitialized = true;
    }

    _session?.release();

    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw FileSystemException('Geo-model file not found', modelPath);
    }

    final bytes = await modelFile.readAsBytes();
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    sessionOptions
        .release(); // options are consumed by fromBuffer; release native memory

    debugPrint('[GeoModel] model loaded from $modelPath');
    debugPrint('[GeoModel] input: $_inputName, output: $_outputName');
  }

  /// Release all resources.
  void dispose() {
    _session?.release();
    _session = null;
    _labels = const [];
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
  Map<String, double> predict({
    required double latitude,
    required double longitude,
    required int week,
  }) {
    if (!isReady) {
      throw StateError('GeoModel not ready. Call loadLabels() + loadModel().');
    }

    assert(week >= 1 && week <= 48, 'week must be 1–48, got $week');

    // Build input tensor: [1, 3] = [lat, lon, week]
    final inputData = Float32List.fromList([
      latitude,
      longitude,
      week.toDouble(),
    ]);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3],
    );

    final runOptions = OrtRunOptions();

    try {
      // Run inference.
      final inputs = {_inputName: inputTensor};
      final outputs = _session!.run(runOptions, inputs);

      // Extract output probabilities.
      final outputValue = outputs.firstOrNull;
      if (outputValue == null) {
        throw StateError('Geo-model returned no output');
      }
      final rawOutput = outputValue.value;

      // The output is typically List<List<double>> for shape [1, N].
      List<double> probabilities;
      if (rawOutput is List<List<double>>) {
        probabilities = rawOutput.first;
      } else if (rawOutput is List) {
        // Flatten if needed.
        probabilities = rawOutput.cast<double>();
      } else {
        throw StateError(
            'Unexpected geo-model output type: ${rawOutput.runtimeType}');
      }

      // Build the result map.
      final scores = <String, double>{};
      final count = probabilities.length < _labels.length
          ? probabilities.length
          : _labels.length;
      for (var i = 0; i < count; i++) {
        scores[_labels[i].scientificName] = probabilities[i];
      }

      // Release output tensors.
      for (final o in outputs) {
        o?.release();
      }

      return scores;
    } finally {
      // Release native resources.
      inputTensor.release();
      runOptions.release();
    }
  }

  /// Return the subset of species whose geo-model score meets [threshold],
  /// sorted by descending probability.
  ///
  /// Returns a list of [GeoSpeciesScore] tuples.
  List<GeoSpeciesScore> expectedSpecies({
    required double latitude,
    required double longitude,
    required int week,
    double threshold = 0.03,
  }) {
    final scores = predict(
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
            id: 0,
            scientificName: entry.key,
            commonName: entry.key,
          ),
        );
        results.add(GeoSpeciesScore(
          scientificName: entry.key,
          commonName: label.commonName,
          score: entry.value,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Return geo-model scores as a map (for use with [SpeciesFilter]).
  Map<String, double> geoScoresForFilter({
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
