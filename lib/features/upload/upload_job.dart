// =============================================================================
// Upload Job — one session going to one destination
// =============================================================================
//
// A job is created when the user ticks a destination in the Share dialog or
// when ARU auto-upload fires. It carries the export configuration it was
// queued with so a restart does not change what gets uploaded. Finished jobs
// stay in the store as the upload log; the version counter lets a session be
// uploaded again after an edit without touching the earlier copy.
// =============================================================================

import '../history/services/share_export_config.dart';

enum UploadJobState { queued, uploading, uploaded, failed }

class UploadJob {
  UploadJob({
    required this.id,
    required this.sessionId,
    required this.sessionUuid,
    required this.destinationId,
    required this.version,
    required this.config,
    this.state = UploadJobState.queued,
    this.attempts = 0,
    required DateTime createdAt,
    DateTime? nextAttemptAt,
    DateTime? finishedAt,
    this.lastError,
    this.remotePath,
  }) : createdAt = createdAt.toUtc(),
       nextAttemptAt = nextAttemptAt?.toUtc(),
       finishedAt = finishedAt?.toUtc();

  /// Attempts after which a job stops retrying on its own.
  static const int maxAttempts = 30;

  final String id;
  final String sessionId;
  final String sessionUuid;
  final String destinationId;

  /// 1 for the first upload of a session to a destination, 2 for the next.
  final int version;
  final ShareExportConfig config;
  final UploadJobState state;
  final int attempts;
  final DateTime createdAt;

  /// When a failed job may be retried; null once it gave up.
  final DateTime? nextAttemptAt;
  final DateTime? finishedAt;

  /// Short machine code of the last failure (see UploadService), for l10n.
  final String? lastError;

  /// Remote folder (or flat-name prefix) the files went to.
  final String? remotePath;

  /// Still waiting for its turn, including scheduled retries.
  bool get isPending =>
      state == UploadJobState.queued ||
      state == UploadJobState.uploading ||
      (state == UploadJobState.failed && nextAttemptAt != null);

  bool get gaveUp => state == UploadJobState.failed && nextAttemptAt == null;

  bool isDue(DateTime now) {
    if (state == UploadJobState.queued) return true;
    if (state == UploadJobState.failed) {
      final at = nextAttemptAt;
      return at != null && !at.isAfter(now.toUtc());
    }
    return false;
  }

  UploadJob copyWith({
    UploadJobState? state,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    DateTime? finishedAt,
    String? lastError,
    bool clearError = false,
    String? remotePath,
  }) {
    return UploadJob(
      id: id,
      sessionId: sessionId,
      sessionUuid: sessionUuid,
      destinationId: destinationId,
      version: version,
      config: config,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
      nextAttemptAt: clearNextAttempt
          ? null
          : (nextAttemptAt ?? this.nextAttemptAt),
      finishedAt: finishedAt ?? this.finishedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      remotePath: remotePath ?? this.remotePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'sessionUuid': sessionUuid,
    'destinationId': destinationId,
    'version': version,
    'config': config.toJson(),
    'state': state.name,
    'attempts': attempts,
    'createdAt': createdAt.toIso8601String(),
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
    if (remotePath != null) 'remotePath': remotePath,
  };

  factory UploadJob.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return UploadJob(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      sessionUuid: json['sessionUuid'] as String,
      destinationId: json['destinationId'] as String,
      version: json['version'] as int? ?? 1,
      config: ShareExportConfig.fromJson(
        (json['config'] as Map<String, dynamic>?) ?? const {},
      ),
      state: UploadJobState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => UploadJobState.queued,
      ),
      attempts: json['attempts'] as int? ?? 0,
      createdAt:
          date('createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      nextAttemptAt: date('nextAttemptAt'),
      finishedAt: date('finishedAt'),
      lastError: json['lastError'] as String?,
      remotePath: json['remotePath'] as String?,
    );
  }

  @override
  String toString() =>
      'UploadJob($sessionId -> $destinationId v$version ${state.name})';
}
