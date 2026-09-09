// =============================================================================
// ARU Controller - Pure state machine skeleton for scheduled deployments
// =============================================================================

import '../live/live_session.dart';
import '../recording/recording_service.dart';
import '../survey/detection_sampler.dart';
import 'aru_detection_sampler.dart';
import 'aru_schedule.dart';

/// Lifecycle state of an ARU deployment.
enum AruControllerState {
  idle,
  preparing,
  waiting,
  recording,
  finalizingCycle,
  recovering,
  stopping,
  completed,
  error,
}

/// Persists an ARU session after a state transition.
typedef AruSessionSaver = Future<void> Function(LiveSession session);

/// Deletes a saved ARU session record without touching shared recordings.
typedef AruSessionDiscarder = Future<void> Function(String sessionId);

/// Starts audio capture for a scheduled ARU cycle.
typedef AruCycleRecordingStarter =
    Future<String?> Function(LiveSession session, AruCycleWindow window);

/// Stops audio capture for the active ARU cycle.
typedef AruCycleRecordingStopper =
    Future<String?> Function(
      LiveSession session,
      AruCycleMetadata cycle,
      DateTime endedAt,
    );

/// Cuts detection-only clips for a batch of records while a cycle is
/// recording, all from the same slice of audio.
///
/// Batched rather than per-record so a sync round costs one post-roll wait and
/// anchors every clip in the round to the same moment — the Live and Survey
/// inference loops cut their clips the same way. Returns the written path per
/// record; records whose clip could not be written are absent from the map.
typedef AruDetectionClipSaver =
    Future<Map<DetectionRecord, String>> Function(
      LiveSession session,
      List<DetectionRecord> records,
    );

/// Minimal ARU controller that owns schedule transitions and session metadata.
///
/// Audio capture, inference, notifications, and platform recovery can be wired
/// onto this state machine later. This class intentionally has no Flutter or
/// platform dependencies, making the scheduling behavior unit-testable.
class AruController {
  AruController({
    required AruSessionSaver saveSession,
    AruSessionDiscarder? discardSession,
    AruCycleRecordingStarter? startCycleRecording,
    AruCycleRecordingStopper? stopCycleRecording,
    AruDetectionClipSaver? saveDetectionClips,
    DateTime Function()? now,
  }) : _saveSession = saveSession,
       _discardSession = discardSession,
       _startCycleRecording = startCycleRecording,
       _stopCycleRecording = stopCycleRecording,
       _saveDetectionClips = saveDetectionClips,
       _now = now ?? DateTime.now;

  final AruSessionSaver _saveSession;
  final AruSessionDiscarder? _discardSession;
  final AruCycleRecordingStarter? _startCycleRecording;
  final AruCycleRecordingStopper? _stopCycleRecording;
  final AruDetectionClipSaver? _saveDetectionClips;
  final DateTime Function() _now;

  AruControllerState _state = AruControllerState.idle;
  LiveSession? _session;
  AruScheduleCalculator? _calculator;
  String? _errorMessage;
  int? _activeCycleIndex;
  DateTime? _activeCycleStart;
  AruDetectionSampler? _sampler;
  final DetectionClipPeakTracker _clipPeakTracker = DetectionClipPeakTracker();
  LiveSession? _lastReviewSession;

  AruControllerState get state => _state;
  LiveSession? get session => _session;
  String? get errorMessage => _errorMessage;

  /// Session to open in review after the deployment ends, or null when there is
  /// nothing reviewable.
  ///
  /// For per-cycle deployments whose aggregate is discarded on completion
  /// ([_shouldDiscardAggregateSession]), the aggregate must never be offered for
  /// review. `_lastReviewSession` is pre-seeded with the aggregate at start and
  /// only replaced by a real per-cycle session once a cycle completes; if none
  /// did (e.g. the user stops during the first `waiting` window), the resolved
  /// candidate is still the aggregate, so this returns null instead of the
  /// just-discarded session.
  LiveSession? get reviewSession {
    final candidate = _lastReviewSession ?? _session;
    if (candidate == null) return null;
    final aggregate = _session;
    if (aggregate != null &&
        identical(candidate, aggregate) &&
        _shouldDiscardAggregateSession(aggregate)) {
      return null;
    }
    return candidate;
  }

  Future<void> restoreDeployment(LiveSession session, {DateTime? now}) async {
    if (session.type != SessionType.aru || session.aruMetadata == null) {
      throw ArgumentError('Session is not an ARU deployment');
    }
    if (session.endTime != null) {
      throw ArgumentError('ARU deployment is already completed');
    }
    if (_state != AruControllerState.idle &&
        _state != AruControllerState.completed &&
        _state != AruControllerState.error) {
      throw StateError('ARU deployment already started');
    }

    _state = AruControllerState.recovering;
    _errorMessage = null;
    _session = session;
    _calculator = AruScheduleCalculator(
      session.aruMetadata!.toScheduleConfig(),
    );
    _activeCycleIndex = null;
    _activeCycleStart = null;
    _clipPeakTracker.clear();
    _lastReviewSession = session;
    _sampler = AruDetectionSampler(
      mode: samplingModeFromString(session.aruMetadata!.samplingMode),
      topN: session.aruMetadata!.topNPerSpecies,
      scopeKeyFor: _samplingScopeKeyFor,
    );

    _normalizeRecoveredCycles(now ?? _now());
    await evaluate(now: now ?? _now());
  }

  Future<void> startDeployment({
    required String sessionId,
    required SessionSettings settings,
    required AruDeploymentMetadata metadata,
    String? observerName,
    double? latitude,
    double? longitude,
    int? sessionNumber,
  }) async {
    if (_state != AruControllerState.idle &&
        _state != AruControllerState.completed &&
        _state != AruControllerState.error) {
      throw StateError('ARU deployment already started');
    }

    _state = AruControllerState.preparing;
    _errorMessage = null;
    _activeCycleIndex = null;
    _activeCycleStart = null;
    _clipPeakTracker.clear();

    try {
      _calculator = AruScheduleCalculator(metadata.toScheduleConfig());
      _session = LiveSession(
        id: sessionId,
        type: SessionType.aru,
        startTime: metadata.scheduleStart,
        customName: _deploymentSessionName(metadata),
        settings: settings,
        observerName: observerName,
        latitude: latitude,
        longitude: longitude,
        aruMetadata: metadata,
        sessionNumber: sessionNumber,
      );
      _lastReviewSession = _session;
      _sampler = AruDetectionSampler(
        mode: samplingModeFromString(metadata.samplingMode),
        topN: metadata.topNPerSpecies,
        scopeKeyFor: _samplingScopeKeyFor,
      );
      await _persist();
      await evaluate(now: _now());
    } catch (e) {
      _state = AruControllerState.error;
      _errorMessage = e.toString();
      rethrow;
    }
  }

  /// Re-evaluate the schedule and transition between waiting/recording states.
  ///
  /// When [recordingSuppressed] is true (e.g. the runner has paused for low
  /// battery), a scheduled recording window is skipped without starting capture
  /// or inference: the cycle is recorded as [AruCycleStatus.skipped] and the
  /// controller stays in a non-recording state until the next window. The
  /// decision is made once per window — a window already entered or skipped is
  /// never re-recorded even if the battery recovers mid-window.
  Future<bool> evaluate({
    DateTime? now,
    bool recordingSuppressed = false,
  }) async {
    if (_state == AruControllerState.completed ||
        _state == AruControllerState.stopping) {
      return false;
    }

    final session = _requireSession();
    final calculator = _calculator;
    if (calculator == null) {
      throw StateError('ARU schedule is not initialized');
    }

    final evalTime = now ?? _now();
    final snapshot = calculator.snapshotAt(evalTime);
    var changed = false;
    switch (snapshot.status) {
      case AruScheduleStatus.notStarted:
      case AruScheduleStatus.waiting:
        changed |= await _leaveActiveCycle(
          status: AruCycleStatus.completed,
          endedAt: evalTime,
        );
        changed |= _setState(AruControllerState.waiting);
        break;
      case AruScheduleStatus.recording:
        final window = snapshot.currentWindow!;
        final existing = _cycleAt(window.index);
        final alreadyDecided =
            existing != null &&
            existing.status != AruCycleStatus.scheduled &&
            existing.status != AruCycleStatus.recording;
        if (alreadyDecided) {
          // This window was already finalized (recorded or skipped); do not
          // re-enter it. Wait for the next scheduled window.
          changed |= await _leaveActiveCycle(
            status: AruCycleStatus.completed,
            endedAt: evalTime,
          );
          changed |= _setState(AruControllerState.waiting);
        } else if (recordingSuppressed) {
          changed |= await _skipCycle(window, evalTime);
          changed |= _setState(AruControllerState.waiting);
        } else {
          changed |= await _enterCycle(window);
          changed |= _setState(AruControllerState.recording);
        }
        break;
      case AruScheduleStatus.completed:
        changed |= await _leaveActiveCycle(
          status: AruCycleStatus.completed,
          endedAt: evalTime,
        );
        if (session.endTime != evalTime) {
          session.endTime = evalTime;
          changed = true;
        }
        changed |= _setState(AruControllerState.completed);
        break;
    }

    if (changed) await _persist();
    return changed;
  }

  Future<void> syncDetections(List<DetectionRecord> records) async {
    final session = _session;
    if (session == null || records.isEmpty) return;

    // Pass 1 — pair each incoming record with the one already in the session
    // and work out which of them want a clip cut from the audio available
    // right now. Deciding up front lets the whole round share one post-roll
    // wait and one slice of audio, exactly as the Live and Survey inference
    // loops do it.
    final pairs = <_DetectionSyncPair>[];
    final wantsClip = <DetectionRecord>[];
    final savesClips =
        recordingModeFromString(
          session.aruMetadata?.recordingMode ?? RecordingMode.off.name,
        ) ==
        RecordingMode.detectionsOnly;

    for (final record in records) {
      final index = _detectionIndex(session.detections, record);
      final existing = index == -1 ? null : session.detections[index];
      pairs.add(_DetectionSyncPair(record, existing, index));
      if (savesClips && _wantsDetectionClip(record, existing)) {
        wantsClip.add(record);
      }
    }

    // Date the analyzed window before the saver waits for post-roll. Using
    // the clock after that await shifts the claimed window forward by exactly
    // the configured clip context.
    final clipWindowStart = _now().subtract(
      Duration(seconds: session.settings.windowDuration),
    );
    final clips =
        wantsClip.isEmpty
            ? const <DetectionRecord, String>{}
            : await _saveDetectionClips?.call(session, wantsClip) ??
                const <DetectionRecord, String>{};

    // Pass 2 — apply. `addDetection` appends, so the indices captured above
    // still point at the same records.
    var changed = false;
    final supersededClipPaths = <String>[];
    for (final pair in pairs) {
      final synced = await _syncedDetectionRecord(pair, clips, clipWindowStart);

      if (pair.index == -1) {
        session.addDetection(synced);
        changed = true;
      } else if (!_sameDetectionPayload(pair.existing!, synced)) {
        session.detections[pair.index] = synced;
        _sampler?.replaceRecord(pair.existing!, synced);
        changed = true;
      }
      final fresh = clips[pair.record];
      final previous = pair.existing?.audioClipPath;
      if (fresh != null) {
        _clipPeakTracker.recordSaved(
          _detectionClipKey(pair.record),
          pair.record.confidence,
        );
        if (previous != null && previous != fresh) {
          supersededClipPaths.add(previous);
        }
      }
    }
    // Every session record points at its fresh file before deletion can yield
    // to cycle finalization.
    for (final path in supersededClipPaths) {
      await deleteDetectionClipFile(path, logTag: 'AruController');
    }
    if (!changed) return;

    _updateCycleDetectionStats(session);
    await _persist();
  }

  /// Whether [record] wants a clip cut from the audio in the ring buffer now.
  ///
  /// Only while the detection is still open: once the species has stopped
  /// vocalizing the buffer holds later, unrelated audio. Beyond that the
  /// decision is [DetectionClipPeakTracker.needsClip]'s — the same rule Live
  /// and Survey apply.
  bool _wantsDetectionClip(DetectionRecord record, DetectionRecord? existing) {
    final closesNow =
        record.endTimestamp != null && existing?.endTimestamp == null;
    if (existing != null && (closesNow || existing.endTimestamp != null)) {
      return false;
    }
    return _clipPeakTracker.needsClip(
      key: _detectionClipKey(record),
      candidateConfidence: record.confidence,
      currentConfidence: existing?.confidence ?? record.confidence,
      hasClip: (existing?.audioClipPath ?? record.audioClipPath) != null,
      isNew: existing == null,
    );
  }

  Future<DetectionRecord> _syncedDetectionRecord(
    _DetectionSyncPair pair,
    Map<DetectionRecord, String> clips,
    DateTime clipWindowStart,
  ) async {
    final record = pair.record;
    final existing = pair.existing;
    var audioClipPath = existing?.audioClipPath ?? record.audioClipPath;
    var clipTimestamp = existing?.clipTimestamp ?? record.clipTimestamp;
    final clipKey = _detectionClipKey(record);
    final closesNow =
        record.endTimestamp != null && existing?.endTimestamp == null;

    // A clip is cut the moment the species first appears — while the analyzed
    // audio is still fresh in the ring buffer — and re-cut whenever the
    // detection reaches a new confidence peak. A merged detection spans many
    // windows but a clip holds one, and the first window is typically its
    // weakest, so the clip has to follow the peak.
    final fresh = clips[record];
    if (fresh != null) {
      audioClipPath = fresh;
      clipTimestamp = clipWindowStart;
    } else if (existing == null && audioClipPath != null) {
      // Arrived with a clip already attached: adopt its score as the baseline
      // so later peaks are measured against the audio actually on disk.
      _clipPeakTracker.recordSaved(clipKey, record.confidence);
    }

    final synced = DetectionRecord(
      scientificName: record.scientificName,
      commonName: record.commonName,
      confidence:
          existing != null && existing.confidence > record.confidence
              ? existing.confidence
              : record.confidence,
      timestamp: record.timestamp,
      endTimestamp: record.endTimestamp ?? existing?.endTimestamp,
      audioClipPath: audioClipPath,
      clipTimestamp: audioClipPath == null ? null : clipTimestamp,
      source: record.source,
      latitude: record.latitude ?? existing?.latitude,
      longitude: record.longitude ?? existing?.longitude,
      // A reviewer decision on the record already in the session wins over
      // whatever the incoming record carries; fall back to the incoming one
      // only when the existing record is still unreviewed.
      reviewStatus:
          (existing != null && existing.isReviewed)
              ? existing.reviewStatus
              : record.reviewStatus,
      reviewedAt:
          (existing != null && existing.isReviewed)
              ? existing.reviewedAt
              : record.reviewedAt,
      note: existing?.note ?? record.note,
      voiceMemoPath: existing?.voiceMemoPath ?? record.voiceMemoPath,
    );

    if (closesNow) {
      await _sampler?.onRecordClosed(synced);
      _clipPeakTracker.forget(clipKey);
    }

    return synced;
  }

  int _detectionIndex(List<DetectionRecord> records, DetectionRecord target) {
    return records.indexWhere(
      (record) =>
          record.scientificName == target.scientificName &&
          record.timestamp == target.timestamp,
    );
  }

  String _detectionClipKey(DetectionRecord record) =>
      '${record.scientificName}\u0000'
      '${record.timestamp.microsecondsSinceEpoch}';

  bool _sameDetectionPayload(DetectionRecord a, DetectionRecord b) {
    return a.scientificName == b.scientificName &&
        a.commonName == b.commonName &&
        a.confidence == b.confidence &&
        a.timestamp == b.timestamp &&
        a.endTimestamp == b.endTimestamp &&
        a.audioClipPath == b.audioClipPath &&
        a.clipTimestamp == b.clipTimestamp &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude &&
        a.reviewStatus == b.reviewStatus &&
        a.reviewedAt == b.reviewedAt &&
        a.note == b.note &&
        a.voiceMemoPath == b.voiceMemoPath;
  }

  void _updateCycleDetectionStats(LiveSession session) {
    final cycles = session.aruMetadata?.cycles;
    if (cycles == null) return;
    final tracksClips =
        recordingModeFromString(
          session.aruMetadata?.recordingMode ?? RecordingMode.off.name,
        ) ==
        RecordingMode.detectionsOnly;

    for (final cycle in cycles) {
      final detections = _detectionsInWindow(
        session,
        cycle.plannedStart,
        cycle.plannedEnd,
      );
      final retainedClipCount =
          detections
              .where((detection) => detection.audioClipPath != null)
              .length;
      _upsertCycle(
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: cycle.actualEnd,
          status: cycle.status,
          recordingPath: cycle.recordingPath,
          detectionCount: detections.length,
          retainedClipCount: retainedClipCount,
          droppedClipCount:
              tracksClips
                  ? (detections.length - retainedClipCount).clamp(
                    0,
                    detections.length,
                  )
                  : cycle.droppedClipCount,
          note: cycle.note,
        ),
      );
    }
  }

  List<DetectionRecord> _detectionsInWindow(
    LiveSession session,
    DateTime start,
    DateTime end,
  ) {
    return session.detections.where((detection) {
      return !detection.timestamp.isBefore(start) &&
          detection.timestamp.isBefore(end);
    }).toList();
  }

  /// Stop the deployment manually or because a guard fired.
  Future<LiveSession> stop({
    SessionStopReason reason = SessionStopReason.manual,
    num? reasonValue,
    DateTime? now,
  }) async {
    final session = _requireSession();
    final stopTime = now ?? _now();

    _state = AruControllerState.stopping;
    await _leaveActiveCycle(status: AruCycleStatus.stopped, endedAt: stopTime);
    session.stopReason = reason;
    session.stopReasonValue = reasonValue;
    session.endTime = stopTime;
    _state = AruControllerState.completed;
    await _persist();
    return session;
  }

  LiveSession _requireSession() {
    final session = _session;
    if (session == null) throw StateError('No ARU deployment is active');
    return session;
  }

  bool _setState(AruControllerState state) {
    if (_state == state) return false;
    _state = state;
    return true;
  }

  Future<bool> _enterCycle(AruCycleWindow window) async {
    final session = _requireSession();
    if (_activeCycleIndex == window.index) return false;

    var changed = await _leaveActiveCycle(
      status: AruCycleStatus.completed,
      endedAt: window.start,
    );

    _activeCycleIndex = window.index;
    _activeCycleStart = window.start;
    session.segments.add(SessionSegment(startTime: window.start));
    changed = true;
    final recordingMode = recordingModeFromString(
      session.aruMetadata?.recordingMode ?? RecordingMode.off.name,
    );
    final recordingPath =
        recordingMode == RecordingMode.off
            ? null
            : await _startCycleRecording?.call(session, window);
    _upsertCycle(
      AruCycleMetadata(
        index: window.index,
        plannedStart: window.start,
        plannedEnd: window.plannedEnd,
        actualStart: window.start,
        status: AruCycleStatus.recording,
        recordingPath: recordingPath,
      ),
    );
    return changed;
  }

  /// Skip a scheduled recording window because recording is currently
  /// suppressed (low battery). Finalizes any in-progress cycle as partial and
  /// records the window as [AruCycleStatus.skipped] without starting capture or
  /// inference or producing a per-cycle session.
  Future<bool> _skipCycle(AruCycleWindow window, DateTime now) async {
    final session = _session;
    if (session == null) return false;

    var changed = false;
    if (_activeCycleIndex != null) {
      changed |= await _leaveActiveCycle(
        status: AruCycleStatus.partial,
        endedAt: now,
      );
    }

    if (_cycleAt(window.index) == null) {
      _upsertCycle(
        AruCycleMetadata(
          index: window.index,
          plannedStart: window.start,
          plannedEnd: window.plannedEnd,
          status: AruCycleStatus.skipped,
        ),
      );
      changed = true;
    }
    return changed;
  }

  Future<bool> _leaveActiveCycle({
    required AruCycleStatus status,
    required DateTime endedAt,
  }) async {
    final session = _session;
    final index = _activeCycleIndex;
    final startedAt = _activeCycleStart;
    if (session == null || index == null || startedAt == null) return false;

    final existing = _cycleAt(index);
    final effectiveEnd =
        status == AruCycleStatus.completed &&
                existing != null &&
                endedAt.isAfter(existing.plannedEnd)
            ? existing.plannedEnd
            : endedAt;

    if (session.segments.isNotEmpty) {
      final last = session.segments.last;
      last.endTime ??= effectiveEnd;
    }
    session.accumulateRecordedSeconds(
      effectiveEnd.difference(startedAt).inSeconds,
    );

    final stoppedPath = await _stopCycleRecording?.call(
      session,
      existing ??
          AruCycleMetadata(
            index: index,
            plannedStart: startedAt,
            plannedEnd: effectiveEnd,
            actualStart: startedAt,
            status: status,
          ),
      effectiveEnd,
    );

    final finalizedCycle = AruCycleMetadata(
      index: index,
      plannedStart: existing?.plannedStart ?? startedAt,
      plannedEnd: existing?.plannedEnd ?? effectiveEnd,
      actualStart: existing?.actualStart ?? startedAt,
      actualEnd: effectiveEnd,
      status: status,
      recordingPath: stoppedPath ?? existing?.recordingPath,
      detectionCount: existing?.detectionCount ?? 0,
      retainedClipCount: existing?.retainedClipCount ?? 0,
      droppedClipCount: existing?.droppedClipCount ?? 0,
      note: existing?.note,
    );
    _upsertCycle(finalizedCycle);

    final eachCycleIsSession = session.aruMetadata?.eachCycleIsSession ?? false;
    // Combined deployments deliberately record detections-only (see
    // _effectiveAruRecordingMode in aru_setup_screen.dart), so they never own a
    // single full-length recording. Per-cycle audio, when present, is tracked on
    // each cycle's metadata (finalizedCycle.recordingPath); the aggregate session
    // stays clips-only and must not claim a single recordingPath that would point
    // at just the last cycle. Segmented playback of combined cycles is a separate
    // future feature (see dev/aru_mode_todo.md). Per-cycle sessions below get
    // their own standalone recordingPath instead.

    if (eachCycleIsSession) {
      final cycleDetections = _detectionsInWindow(
        session,
        startedAt,
        effectiveEnd,
      );

      final cycleSession = LiveSession(
        id: '${session.id}_cycle_$index',
        type: SessionType.aru,
        sessionNumber: session.sessionNumber,
        startTime: startedAt,
        endTime: effectiveEnd,
        customName: _cycleSessionName(session, index),
        settings: session.settings,
        observerName: session.observerName,
        latitude: session.latitude,
        longitude: session.longitude,
        recordingPath: stoppedPath ?? existing?.recordingPath,
        detections: cycleDetections,
        aruMetadata: _cycleDeploymentMetadata(
          session,
          finalizedCycle,
          cycleDetections.length,
        ),
      );

      await _saveSession(cycleSession);
      _lastReviewSession = cycleSession;
    } else {
      _lastReviewSession = session;
    }

    _activeCycleIndex = null;
    _activeCycleStart = null;
    return true;
  }

  AruCycleMetadata? _cycleAt(int index) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return null;
    for (final cycle in cycles) {
      if (cycle.index == index) return cycle;
    }
    return null;
  }

  AruCycleMetadata? _cycleFor(DetectionRecord record) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return null;
    for (final cycle in cycles) {
      if (!record.timestamp.isBefore(cycle.plannedStart) &&
          record.timestamp.isBefore(cycle.plannedEnd)) {
        return cycle;
      }
    }
    return null;
  }

  String _samplingScopeKeyFor(DetectionRecord record) {
    final metadata = _session?.aruMetadata;
    final sessionId = _session?.id ?? 'active';
    if (metadata?.eachCycleIsSession == true) {
      return 'session:${sessionId}_cycle_${_cycleFor(record)?.index ?? _activeCycleIndex ?? 0}';
    }
    return 'session:$sessionId';
  }

  bool _shouldDiscardAggregateSession(LiveSession session) {
    final metadata = session.aruMetadata;
    if (metadata == null) return false;
    // "One session per cycle" deployments keep only their per-cycle sessions;
    // the aggregate is never part of the final library, regardless of recording
    // mode. (It is still persisted while the deployment runs so it can be
    // restored after a process kill — see _persist.)
    return metadata.eachCycleIsSession;
  }

  Future<void> _discardAggregateSession(LiveSession session) async {
    final discard = _discardSession;
    if (discard == null || !_shouldDiscardAggregateSession(session)) return;
    await discard(session.id);
  }

  void _upsertCycle(AruCycleMetadata cycle) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return;
    final existingIndex = cycles.indexWhere((c) => c.index == cycle.index);
    if (existingIndex >= 0) {
      cycles[existingIndex] = cycle;
    } else {
      cycles.add(cycle);
      cycles.sort((a, b) => a.index.compareTo(b.index));
    }
  }

  void _normalizeRecoveredCycles(DateTime now) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return;

    for (final cycle in cycles.toList()) {
      if (cycle.status != AruCycleStatus.recording) continue;
      // If the recording window is still active, leave the cycle marked as
      // recording so evaluate() resumes capture in the same cycle instead of
      // abandoning it and waiting for the next window. Only cycles whose window
      // already elapsed while the app was down are finalized as partial.
      if (now.isBefore(cycle.plannedEnd)) continue;
      final end = now.isAfter(cycle.plannedEnd) ? cycle.plannedEnd : now;
      _upsertCycle(
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: end,
          status: AruCycleStatus.partial,
          recordingPath: cycle.recordingPath,
          detectionCount: cycle.detectionCount,
          retainedClipCount: cycle.retainedClipCount,
          droppedClipCount: cycle.droppedClipCount,
          note: cycle.note,
        ),
      );
    }
  }

  Future<void> _persist() async {
    final session = _session;
    if (session == null) return;
    // Per-cycle deployments persist the aggregate while in progress so an
    // interrupted deployment can be restored from disk (restore looks for an
    // ARU session with endTime == null). Once completed, the aggregate is
    // discarded so only the per-cycle sessions remain in the library.
    if (_shouldDiscardAggregateSession(session)) {
      if (_state == AruControllerState.completed) {
        await _discardAggregateSession(session);
      } else {
        await _saveSession(session);
      }
      return;
    }
    await _saveSession(session);
  }

  AruDeploymentMetadata? _cycleDeploymentMetadata(
    LiveSession session,
    AruCycleMetadata cycle,
    int detectionCount,
  ) {
    final metadata = session.aruMetadata;
    if (metadata == null) return null;
    return AruDeploymentMetadata(
      deploymentName: metadata.deploymentName,
      stationId: metadata.stationId,
      scheduleStart: cycle.plannedStart,
      cycleDurationSeconds:
          cycle.plannedEnd.difference(cycle.plannedStart).inSeconds,
      repeatIntervalSeconds: metadata.repeatIntervalSeconds,
      scheduleEnd: cycle.actualEnd,
      maxCycles: 1,
      lowBatteryStopPercent: metadata.lowBatteryStopPercent,
      lowBatteryResumePercent: metadata.lowBatteryResumePercent,
      dielPattern: metadata.dielPattern,
      latitude: metadata.latitude,
      longitude: metadata.longitude,
      recordingMode: metadata.recordingMode,
      recordingFormat: metadata.recordingFormat,
      samplingMode: metadata.samplingMode,
      topNPerSpecies: metadata.topNPerSpecies,
      testCycleEnabled: _isTestCycle(session, cycle.index),
      eachCycleIsSession: true,
      cycles: [
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: cycle.actualEnd,
          status: cycle.status,
          recordingPath: cycle.recordingPath,
          detectionCount: detectionCount,
          retainedClipCount: cycle.retainedClipCount,
          droppedClipCount: cycle.droppedClipCount,
          note: cycle.note,
        ),
      ],
    );
  }

  String _cycleSessionName(LiveSession session, int cycleIndex) {
    final isTestRun = _isTestCycle(session, cycleIndex);
    final cyclePart =
        isTestRun
            ? 'Test Run'
            : 'Cycle ${_displayCycleNumber(session, cycleIndex)}';
    final name = session.customName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name - $cyclePart';
    }

    final deploymentNumber = session.sessionNumber;
    final deploymentPart =
        deploymentNumber != null
            ? 'Deployment #$deploymentNumber'
            : 'Deployment';
    return 'ARU $deploymentPart - $cyclePart';
  }

  static String? _deploymentSessionName(AruDeploymentMetadata metadata) {
    final deploymentName = metadata.deploymentName?.trim();
    final stationId = metadata.stationId?.trim();
    final hasDeployment = deploymentName != null && deploymentName.isNotEmpty;
    final hasStation = stationId != null && stationId.isNotEmpty;
    if (hasDeployment && hasStation) return '$deploymentName - $stationId';
    if (hasDeployment) return deploymentName;
    if (hasStation) return stationId;
    return null;
  }

  int _displayCycleNumber(LiveSession session, int cycleIndex) {
    if (session.aruMetadata?.testCycleEnabled == true) {
      return cycleIndex;
    }
    return cycleIndex + 1;
  }

  bool _isTestCycle(LiveSession session, int cycleIndex) {
    return session.aruMetadata?.testCycleEnabled == true && cycleIndex == 0;
  }
}

/// An incoming detection paired with the session record it updates.
///
/// Resolved once per sync round so the clip decision and the record rebuild
/// agree on the pairing without scanning the session twice. [index] is `-1`
/// when the detection is new to the session.
class _DetectionSyncPair {
  _DetectionSyncPair(this.record, this.existing, this.index);

  final DetectionRecord record;
  final DetectionRecord? existing;
  final int index;
}
