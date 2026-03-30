// =============================================================================
// Model Config — JSON-driven configuration for ONNX classification models
// =============================================================================
//
// Decouples the inference pipeline from any specific model by describing the
// model's requirements in a JSON file bundled alongside the `.onnx` weights.
//
// A single config file (`model_config.json`) specifies:
//
// | Section    | What it configures                                     |
// |------------|--------------------------------------------------------|
// | `audio`    | Sample rate, channels expected by the model             |
// | `onnx`     | File name, input/output tensor names                    |
// | `labels`   | File name, delimiter, column mapping for the labels CSV |
// | `inference`| Window sizes, post-processing defaults                  |
//
// ### Usage
//
// ```dart
// final json = await rootBundle.loadString('assets/models/model_config.json');
// final config = ModelConfig.fromJson(jsonDecode(json));
// ```
//
// To swap models, drop a new `.onnx` file, labels CSV, and config JSON into
// `assets/models/` — no code changes required.
// =============================================================================

/// Top-level model configuration loaded from JSON.
///
/// Immutable after construction.  Use [fromJson] to create from a decoded
/// `Map<String, dynamic>`.
class ModelConfig {
  /// Creates a model configuration.
  const ModelConfig({
    required this.name,
    this.version = '',
    this.description = '',
    required this.audio,
    required this.onnx,
    required this.labels,
    required this.inference,
  });

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Human-readable model display name.
  final String name;

  /// Semantic version string (informational only).
  final String version;

  /// Optional longer description of what the model does.
  final String description;

  /// Audio input requirements.
  final AudioConfig audio;

  /// ONNX file and tensor configuration.
  final OnnxConfig onnx;

  /// Labels CSV file and column mapping.
  final LabelsConfig labels;

  /// Inference pipeline defaults.
  final InferenceDefaults inference;

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  /// Deserialize from a decoded JSON map.
  ///
  /// Throws [FormatException] or [TypeError] if required fields are missing or
  /// have the wrong type.
  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      name: json['name'] as String,
      version: json['version'] as String? ?? '',
      description: json['description'] as String? ?? '',
      audio: AudioConfig.fromJson(json['audio'] as Map<String, dynamic>),
      onnx: OnnxConfig.fromJson(json['onnx'] as Map<String, dynamic>),
      labels: LabelsConfig.fromJson(json['labels'] as Map<String, dynamic>),
      inference:
          InferenceDefaults.fromJson(json['inference'] as Map<String, dynamic>),
    );
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'description': description,
        'audio': audio.toJson(),
        'onnx': onnx.toJson(),
        'labels': labels.toJson(),
        'inference': inference.toJson(),
      };
}

// =============================================================================
// Audio Config
// =============================================================================

/// Audio format expected by the model.
class AudioConfig {
  const AudioConfig({
    required this.sampleRate,
    this.channels = 1,
  });

  /// Sample rate in Hz (e.g. 32 000, 44 100, 48 000).
  final int sampleRate;

  /// Number of audio channels (typically 1 for mono).
  final int channels;

  factory AudioConfig.fromJson(Map<String, dynamic> json) {
    return AudioConfig(
      sampleRate: json['sampleRate'] as int,
      channels: json['channels'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'channels': channels,
      };
}

// =============================================================================
// ONNX Config
// =============================================================================

/// ONNX model file and tensor naming.
class OnnxConfig {
  const OnnxConfig({
    required this.modelFile,
    this.inputName = 'input',
    this.outputNames = const {'predictions': 'predictions'},
  });

  /// File name of the `.onnx` model (relative to the config file's directory).
  final String modelFile;

  /// Name of the input tensor.
  final String inputName;

  /// Map from logical output name to ONNX tensor name.
  ///
  /// Must contain at least `"predictions"`.  May optionally contain
  /// `"embeddings"` for feature-vector extraction.
  ///
  /// Example: `{"predictions": "output_0", "embeddings": "output_1"}`
  final Map<String, String> outputNames;

  /// ONNX tensor name for the predictions output.
  String get predictionsName => outputNames['predictions'] ?? 'predictions';

  /// ONNX tensor name for embeddings, or `null` if the model doesn't output
  /// embeddings.
  String? get embeddingsName => outputNames['embeddings'];

  factory OnnxConfig.fromJson(Map<String, dynamic> json) {
    final rawOutputs = json['outputNames'];
    final outputNames = rawOutputs is Map
        ? rawOutputs.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const {'predictions': 'predictions'};

    return OnnxConfig(
      modelFile: json['modelFile'] as String,
      inputName: json['inputName'] as String? ?? 'input',
      outputNames: outputNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelFile': modelFile,
        'inputName': inputName,
        'outputNames': outputNames,
      };
}

// =============================================================================
// Labels Config
// =============================================================================

/// Configuration for parsing the labels CSV file.
class LabelsConfig {
  const LabelsConfig({
    required this.file,
    this.delimiter = ';',
    this.hasHeader = true,
    this.columns = const {
      'index': 'idx',
      'id': 'id',
      'scientificName': 'sci_name',
      'commonName': 'com_name',
      'className': 'class',
      'order': 'order',
    },
  });

  /// File name of the labels CSV (relative to the config file's directory).
  final String file;

  /// Column delimiter (e.g. `;`, `,`, `\t`).
  final String delimiter;

  /// Whether the first row is a header row.
  final bool hasHeader;

  /// Mapping from [Species] field names to CSV column header names.
  ///
  /// Recognized keys:
  /// - `index` — zero-based output tensor position (auto-generated from row
  ///   order if omitted or if the CSV has no such column).
  /// - `id` — sparse internal ID (defaults to index if omitted).
  /// - `scientificName` — **required** — binomial name.
  /// - `commonName` — human-readable name (defaults to scientific name).
  /// - `className` — taxonomic class (defaults to empty string).
  /// - `order` — taxonomic order (defaults to empty string).
  final Map<String, String> columns;

  factory LabelsConfig.fromJson(Map<String, dynamic> json) {
    final rawCols = json['columns'];
    final columns = rawCols is Map
        ? rawCols.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, String>{
            'scientificName': 'sci_name',
          };

    return LabelsConfig(
      file: json['file'] as String,
      delimiter: json['delimiter'] as String? ?? ';',
      hasHeader: json['hasHeader'] as bool? ?? true,
      columns: columns,
    );
  }

  Map<String, dynamic> toJson() => {
        'file': file,
        'delimiter': delimiter,
        'hasHeader': hasHeader,
        'columns': columns,
      };
}

// =============================================================================
// Inference Defaults
// =============================================================================

/// Default values for the inference pipeline.
///
/// These can be overridden by user settings at runtime.
class InferenceDefaults {
  const InferenceDefaults({
    this.supportedWindowSeconds = const [3],
    this.defaultWindowSeconds = 3,
    this.defaultSensitivity = 1.0,
    this.defaultConfidenceThreshold = 0.15,
    this.defaultTopK = 10,
    this.temporalPooling = const TemporalPoolingConfig(),
  });

  /// Window durations the model was designed for (seconds).
  final List<int> supportedWindowSeconds;

  /// Default window duration in seconds.
  final int defaultWindowSeconds;

  /// Default sensitivity scaling factor (1.0 = neutral).
  final double defaultSensitivity;

  /// Default minimum confidence to report a detection.
  final double defaultConfidenceThreshold;

  /// Default maximum number of top detections to return.
  final int defaultTopK;

  /// Temporal pooling (Log-Mean-Exp) configuration.
  final TemporalPoolingConfig temporalPooling;

  factory InferenceDefaults.fromJson(Map<String, dynamic> json) {
    final rawWindows = json['supportedWindowSeconds'];
    final windows = rawWindows is List
        ? rawWindows.map((e) => (e as num).toInt()).toList()
        : const [3];

    final rawPooling = json['temporalPooling'];
    final pooling = rawPooling is Map<String, dynamic>
        ? TemporalPoolingConfig.fromJson(rawPooling)
        : const TemporalPoolingConfig();

    return InferenceDefaults(
      supportedWindowSeconds: windows,
      defaultWindowSeconds:
          (json['defaultWindowSeconds'] as num?)?.toInt() ?? 3,
      defaultSensitivity:
          (json['defaultSensitivity'] as num?)?.toDouble() ?? 1.0,
      defaultConfidenceThreshold:
          (json['defaultConfidenceThreshold'] as num?)?.toDouble() ?? 0.15,
      defaultTopK: (json['defaultTopK'] as num?)?.toInt() ?? 10,
      temporalPooling: pooling,
    );
  }

  Map<String, dynamic> toJson() => {
        'supportedWindowSeconds': supportedWindowSeconds,
        'defaultWindowSeconds': defaultWindowSeconds,
        'defaultSensitivity': defaultSensitivity,
        'defaultConfidenceThreshold': defaultConfidenceThreshold,
        'defaultTopK': defaultTopK,
        'temporalPooling': temporalPooling.toJson(),
      };
}

// =============================================================================
// Temporal Pooling Config
// =============================================================================

/// Configuration for Log-Mean-Exp temporal pooling.
class TemporalPoolingConfig {
  const TemporalPoolingConfig({
    this.maxWindows = 5,
    this.alpha = 5.0,
  });

  /// Maximum number of recent inference windows to keep for pooling.
  final int maxWindows;

  /// LME alpha — higher values weight peaks more heavily.
  final double alpha;

  factory TemporalPoolingConfig.fromJson(Map<String, dynamic> json) {
    return TemporalPoolingConfig(
      maxWindows: (json['maxWindows'] as num?)?.toInt() ?? 5,
      alpha: (json['alpha'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxWindows': maxWindows,
        'alpha': alpha,
      };
}
