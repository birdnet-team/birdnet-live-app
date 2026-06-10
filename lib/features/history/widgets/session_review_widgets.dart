part of '../session_review_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Data Models
// ═════════════════════════════════════════════════════════════════════════════

/// Snapshot of mutable review state for undo/redo.
class _ReviewSnapshot {
  _ReviewSnapshot({
    required this.detections,
    required this.annotations,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.clipOffsetSec,
  });

  final List<DetectionRecord> detections;
  final List<SessionAnnotation> annotations;
  final double? trimStartSec;
  final double? trimEndSec;
  final double clipOffsetSec;
}

/// A cluster of consecutive detections of the same species.
class _DetectionCluster {
  _DetectionCluster(this.records) : assert(records.isNotEmpty);

  final List<DetectionRecord> records;

  int get count => records.length;
  DateTime get firstTimestamp => records.first.timestamp;
  DateTime get lastTimestamp => records.last.timestamp;
  double get bestConfidence =>
      records.map((r) => r.confidence).reduce(math.max);
  String get bestConfidencePercent =>
      '${(bestConfidence * 100).toStringAsFixed(1)} %';

  /// Whether any record in this cluster has an existing audio clip file.
  bool get hasAudioClip => records.any(
    (r) => r.audioClipPath != null && File(r.audioClipPath!).existsSync(),
  );
}

/// All detections of one species, subdivided into time-span clusters.
class _SpeciesGroup {
  _SpeciesGroup({
    required this.scientificName,
    required this.commonName,
    required this.clusters,
  });

  final String scientificName;
  final String commonName;
  final List<_DetectionCluster> clusters;

  int get totalCount => clusters.fold<int>(0, (sum, c) => sum + c.count);
  double get bestConfidence =>
      clusters.map((c) => c.bestConfidence).reduce(math.max);
  String get bestConfidencePercent =>
      '${(bestConfidence * 100).toStringAsFixed(1)} %';
  DateTime get firstTimestamp => clusters.first.firstTimestamp;
  DateTime get lastTimestamp => clusters.last.lastTimestamp;

  List<DetectionRecord> get allRecords =>
      clusters.expand((c) => c.records).toList();
}

// ═════════════════════════════════════════════════════════════════════════════
// Summary Header
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryHeader extends ConsumerWidget {
  const _SummaryHeader({
    required this.session,
    required this.detectionCount,
    this.locationName,
    this.onShowMap,
    this.onFetchWeather,
  });

  final LiveSession session;
  final int detectionCount;
  final String? locationName;
  final VoidCallback? onShowMap;
  final Future<void> Function()? onFetchWeather;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final duration = session.duration;
    final species =
        session.detections.map((d) => d.scientificName).toSet().length;
    final dateStr = DateFormat.yMMMd().add_Hm().format(
      session.startTime.toLocal(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(178),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session.weather != null) ...[
                const SizedBox(width: 8),
                _WeatherRow(weather: session.weather!),
              ] else if (session.latitude != null &&
                  session.longitude != null &&
                  !ref.watch(privacyAllowWeatherProvider)) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await ref
                        .read(privacyAllowWeatherProvider.notifier)
                        .set(true);
                    onFetchWeather?.call();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.cloudOff,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.sessionWeatherTapToLoad,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              StatChip(
                icon: AppIcons.timerOutlined,
                value: _formatDuration(duration),
              ),
              const SizedBox(width: 16),
              StatChip(
                icon: AppIcons.species,
                value: l10n.sessionSpeciesCount(species),
              ),
              const SizedBox(width: 16),
              StatChip(
                icon: AppIcons.detections,
                value: l10n.sessionDetectionCount(detectionCount),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (session.latitude != null && session.longitude != null)
            InkWell(
              onTap: onShowMap,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Icon(
                    session.type == SessionType.survey
                        ? AppIcons.flagFilled
                        : AppIcons.locationOn,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationName ??
                          '${session.latitude!.toStringAsFixed(4)}, '
                              '${session.longitude!.toStringAsFixed(4)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    AppIcons.mapSheet,
                    size: 18,
                    color: theme.colorScheme.primary.withAlpha(178),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Icon(
                  AppIcons.locationOff,
                  size: 18,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.sessionNoLocation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ],
            ),
          if (session.weather != null) ...[
            // Weather is rendered inline next to the date row above; no
            // separate block here.
          ],
          // ── Survey-specific info ─────────────────────────
          if (session.type == SessionType.survey) ...[
            if ((session.distanceMeters != null &&
                    session.distanceMeters! > 0) ||
                (session.observerName != null &&
                    session.observerName!.isNotEmpty) ||
                (session.transectId != null &&
                    session.transectId!.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (session.distanceMeters != null &&
                      session.distanceMeters! > 0) ...[
                    StatChip(
                      icon: AppIcons.straighten,
                      value:
                          session.distanceMeters! >= 1000
                              ? '${(session.distanceMeters! / 1000).toStringAsFixed(1)} km'
                              : '${session.distanceMeters!.round()} m',
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (session.observerName != null &&
                      session.observerName!.isNotEmpty) ...[
                    StatChip(
                      icon: AppIcons.personOutline,
                      value: session.observerName!,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (session.transectId != null &&
                      session.transectId!.isNotEmpty) ...[
                    StatChip(
                      icon: AppIcons.routeOutlined,
                      value: session.transectId!,
                    ),
                  ],
                ],
              ),
            ],
            if (session.stopReason != null &&
                session.stopReason != SessionStopReason.manual) ...[
              const SizedBox(height: 6),
              _StopReasonBanner(
                reason: session.stopReason!,
                value: session.stopReasonValue,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}

/// Subtle inline banner that surfaces the auto-stop reason for a survey.
///
/// Hidden when the session was stopped manually or pre-dates the
/// `stopReason` field. Uses the secondary tonal palette so it sits
/// quietly under the other survey stat chips.
class _StopReasonBanner extends StatelessWidget {
  const _StopReasonBanner({required this.reason, required this.value});

  final SessionStopReason reason;
  final num? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final IconData icon;
    final String text;
    switch (reason) {
      case SessionStopReason.maxDuration:
        icon = AppIcons.timerOff;
        text = l10n.sessionAutoStopMaxDuration;
        break;
      case SessionStopReason.lowBattery:
        icon = AppIcons.batteryAlert;
        text = l10n.sessionAutoStopLowBattery((value ?? 0).round());
        break;
      case SessionStopReason.manual:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Weather Row
// ═════════════════════════════════════════════════════════════════════════════

/// Compact weather summary shown under the location row in the session
/// summary header. Tapping the row reveals a details dialog with all
/// captured fields and the Open-Meteo attribution.
class _WeatherRow extends StatelessWidget {
  const _WeatherRow({required this.weather});

  final WeatherSnapshot weather;

  String _conditionLabel(AppLocalizations l10n, WeatherCondition c) {
    switch (c) {
      case WeatherCondition.clear:
        return l10n.weatherCodeClear;
      case WeatherCondition.partlyCloudy:
        return l10n.weatherCodePartlyCloudy;
      case WeatherCondition.cloudy:
        return l10n.weatherCodeCloudy;
      case WeatherCondition.fog:
        return l10n.weatherCodeFog;
      case WeatherCondition.drizzle:
        return l10n.weatherCodeDrizzle;
      case WeatherCondition.rain:
        return l10n.weatherCodeRain;
      case WeatherCondition.snow:
        return l10n.weatherCodeSnow;
      case WeatherCondition.thunder:
        return l10n.weatherCodeThunder;
      case WeatherCondition.unknown:
        return l10n.weatherCodeUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cond = weatherConditionFromCode(weather.weatherCode);
    final inlineLabel = formatWeatherCompactStats(weather);

    return InkWell(
      onTap: () => _showDetails(context, l10n, cond),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              weatherConditionIcon(cond),
              size: 18,
              color: theme.colorScheme.onSurface.withAlpha(178),
            ),
            const SizedBox(width: 4),
            Text(
              inlineLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    AppLocalizations l10n,
    WeatherCondition cond,
  ) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(weatherConditionIcon(cond)),
                const SizedBox(width: 8),
                Text(l10n.sessionWeatherSection),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(l10n.sessionWeatherCondition, _conditionLabel(l10n, cond)),
                _kv(
                  l10n.sessionWeatherTemperature,
                  formatTemperature(weather.temperatureC),
                ),
                _kv(
                  l10n.sessionWeatherWind,
                  formatWind(weather.windSpeedMs, weather.windDirectionDeg),
                ),
                _kv(
                  l10n.sessionWeatherPrecipitation,
                  formatPrecipitation(weather.precipitationMm),
                ),
                _kv(
                  l10n.sessionWeatherCloudCover,
                  formatCloudCover(weather.cloudCoverPercent),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.sessionWeatherAttribution,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
              ),
            ],
          ),
    );
  }

  Widget _kv(String key, String value, {bool showKey = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showKey)
            SizedBox(
              width: 110,
              child: Text(
                key,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Shows a scrollable spectrogram from a pre-computed image.
///
/// The painter derives pixels-per-second from image width / player duration,
/// ensuring perfect alignment regardless of sample rate discrepancies.
class _SpectrogramStrip extends ConsumerStatefulWidget {
  const _SpectrogramStrip({
    required this.session,
    required this.spectrogramImage,
    required this.spectrogramChunks,
    required this.decoding,
    required this.positionNotifier,
    required this.duration,
    required this.timelineOffsetSec,
    required this.onViewportChanged,
    required this.onSeek,
    required this.onPause,
    required this.isPlaying,
    required this.userDefaultViewSeconds,
    this.quality = 'medium',
  });

  final LiveSession session;

  /// Initial / preferred view width for short clips, sourced from the
  /// user's live-spectrogram duration setting. Long files override this
  /// with a duration-aware default so users don't have to pinch out
  /// dozens of times to see any context.
  final double userDefaultViewSeconds;

  final ui.Image? spectrogramImage;
  final List<_SpectrogramChunk> spectrogramChunks;
  final bool decoding;
  final ValueNotifier<Duration> positionNotifier;
  final Duration duration;
  final double timelineOffsetSec;
  final void Function(double absoluteCenterSec, double viewSeconds)?
  onViewportChanged;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPause;
  final bool isPlaying;
  final String quality;

  @override
  ConsumerState<_SpectrogramStrip> createState() => _SpectrogramStripState();
}

class _SpectrogramStripState extends ConsumerState<_SpectrogramStrip>
    with SingleTickerProviderStateMixin {
  /// When non-null the view is pinned to this center (user panned).
  /// When null the view follows the playback position.
  double? _pannedCenterSec;

  late final Ticker _ticker;
  double _interpolatedPositionSec = 0.0;
  DateTime _lastTickTime = DateTime.now();

  double get _viewCenterSec => _pannedCenterSec ?? _interpolatedPositionSec;

  /// Width (in seconds of audio) currently visible in the spectrogram.
  /// Pinch-to-zoom shrinks this for detail and spreads expand it back
  /// toward the default 10 s overview. Bounded so the painter never tries
  /// to render a sub-sample slice or more than the whole clip.
  double _viewSeconds = _defaultViewSeconds;

  /// True once we've snapped [_viewSeconds] to a duration-aware default
  /// for the current clip. Stops the auto-pick from clobbering a manual
  /// pinch-zoom every time `widget.duration` jitters.
  bool _appliedDurationAwareDefault = false;

  /// Captured at the start of a scale gesture so single-finger pans and
  /// two-finger pinches both compose smoothly without integrating drift.
  double? _scaleStartViewSeconds;
  double? _scaleStartCenterSec;
  double? _lastRequestedCenterSec;
  double? _lastRequestedViewSeconds;

  static const double _defaultViewSeconds = 10.0;
  static const double _minViewSeconds = 1.0;
  static const double _maxInitialViewSeconds = 60.0;

  /// Pick an initial view width that scales with clip length: short
  /// recordings (≤ 5 min) open at the user's preferred live-spectrogram
  /// duration; longer ones start showing roughly the first 10 % so users
  /// don't have to pinch-out a dozen times to see context on a one-hour
  /// file.
  double _initialViewSecondsFor(Duration duration) {
    final totalSec = duration.inMicroseconds / 1000000.0;
    final userPref = widget.userDefaultViewSeconds.clamp(
      _minViewSeconds,
      _maxInitialViewSeconds,
    );
    if (totalSec <= 0) return userPref;
    if (totalSec <= 300.0) {
      // Never propose a view wider than the clip itself.
      return math.min(userPref, totalSec);
    }
    final tenPercent = totalSec * 0.1;
    return tenPercent.clamp(userPref, _maxInitialViewSeconds).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _interpolatedPositionSec =
        widget.positionNotifier.value.inMicroseconds / 1000000.0;
    widget.positionNotifier.addListener(_onPositionChanged);
    if (widget.duration > Duration.zero) {
      _viewSeconds = _initialViewSecondsFor(widget.duration);
      _appliedDurationAwareDefault = true;
    }
    _ticker = createTicker((elapsed) {
      if (widget.isPlaying && _pannedCenterSec == null) {
        final now = DateTime.now();
        final delta = now.difference(_lastTickTime).inMicroseconds / 1000000.0;
        setState(() {
          _interpolatedPositionSec += delta;
        });
        _requestVisibleSpectrogram();
        _lastTickTime = now;
      } else {
        _lastTickTime = DateTime.now();
      }
    });
    _ticker.start();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestVisibleSpectrogram(force: true);
    });
  }

  @override
  void didUpdateWidget(_SpectrogramStrip oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.positionNotifier != oldWidget.positionNotifier) {
      oldWidget.positionNotifier.removeListener(_onPositionChanged);
      widget.positionNotifier.addListener(_onPositionChanged);
      _onPositionChanged();
    }

    // First time we learn the true clip length, snap the view to a
    // duration-aware default. Skipped if the user has already pinched
    // or panned, so we never fight a deliberate zoom level. We also
    // force a viewport request so the lazy-loader fetches chunks for
    // the new (potentially much wider) view instead of being stuck on
    // the 10 s request made before duration was known.
    if (!_appliedDurationAwareDefault &&
        widget.duration > Duration.zero &&
        _pannedCenterSec == null &&
        _scaleStartViewSeconds == null) {
      _viewSeconds = _initialViewSecondsFor(widget.duration);
      _appliedDurationAwareDefault = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestVisibleSpectrogram(force: true);
      });
    }

    if (widget.isPlaying && !oldWidget.isPlaying) {
      _lastTickTime = DateTime.now();
    }

    // When playback resumes while the view is panned, seek to the panned
    // position so playback continues from the white center marker.
    if (widget.isPlaying && !oldWidget.isPlaying && _pannedCenterSec != null) {
      final seekTarget = _pannedCenterSec!;
      _pannedCenterSec = null;
      _interpolatedPositionSec = seekTarget;
      widget.onSeek(Duration(microseconds: (seekTarget * 1e6).round()));
    } else if (widget.isPlaying && !oldWidget.isPlaying) {
      _pannedCenterSec = null;
    }

    if (widget.timelineOffsetSec != oldWidget.timelineOffsetSec ||
        widget.duration != oldWidget.duration) {
      _requestVisibleSpectrogram(force: true);
    }

    if (widget.quality != oldWidget.quality) {
      _requestVisibleSpectrogram(force: true);
    }
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_onPositionChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    final actualSec = widget.positionNotifier.value.inMicroseconds / 1000000.0;
    // If we've drifted significantly (more than 100ms), snap it to fix desyncs.
    if ((_interpolatedPositionSec - actualSec).abs() > 0.1) {
      setState(() {
        _interpolatedPositionSec = actualSec;
      });
      _requestVisibleSpectrogram();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasSpectrogram =
        widget.spectrogramImage != null || widget.spectrogramChunks.isNotEmpty;
    if (!hasSpectrogram) {
      return Container(
        height: 150,
        color: Colors.black,
        child:
            widget.decoding
                ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                : null,
      );
    }

    return GestureDetector(
      onTapDown: _handleTap,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      child: Container(
        height: 150,
        color: Colors.black,
        child: Stack(
          children: [
            CustomPaint(
              painter: _ReviewSpectrogramPainter(
                spectrogramImage: widget.spectrogramImage,
                spectrogramChunks: widget.spectrogramChunks,
                centerSec: _viewCenterSec,
                durationSec: widget.duration.inMicroseconds / 1000000.0,
                timelineOffsetSec: widget.timelineOffsetSec,
                viewSeconds: _viewSeconds,
                colorScheme: theme.colorScheme,
                filterQuality: spectrogramFilterQualityFromString(
                  widget.quality,
                ),
                quality: widget.quality,
                session: widget.session,
                tsMode: TimestampDisplayMode.fromString(
                  ref.watch(timestampDisplayModeProvider),
                ),
              ),
              size: const Size(double.infinity, 150),
            ),
            if (widget.decoding)
              Positioned(
                right: 8,
                top: 8,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withAlpha(210),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || widget.duration == Duration.zero) return;
    final viewSeconds = _viewSeconds;
    final startSec = _viewCenterSec - viewSeconds / 2;
    final fraction = details.localPosition.dx / box.size.width;
    final targetSec = startSec + fraction * viewSeconds;
    final clampedMs = (targetSec * 1000).round().clamp(
      0,
      widget.duration.inMilliseconds,
    );
    widget.onSeek(Duration(milliseconds: clampedMs));
    setState(() => _pannedCenterSec = null);
    _requestVisibleSpectrogram(force: true);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Pause playback the moment the user touches the spectrogram so that
    // the panned/zoomed view doesn't fight against the auto-scrolling
    // playhead. Resume happens via the regular play button.
    if (widget.isPlaying) {
      widget.onPause();
    }
    _scaleStartViewSeconds = _viewSeconds;
    _scaleStartCenterSec =
        _pannedCenterSec ??
        widget.positionNotifier.value.inMicroseconds / 1000000.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final durationSec = widget.duration.inMicroseconds / 1000000.0;
    if (durationSec <= 0) return;

    final startView = _scaleStartViewSeconds ?? _viewSeconds;
    final startCenter =
        _scaleStartCenterSec ??
        widget.positionNotifier.value.inMicroseconds / 1000000.0;

    // `details.scale` is *cumulative from gesture start*, not per-frame —
    // so we apply it against the captured `startView` and must NOT reset
    // the start anchor every frame, or each update compounds on the
    // previous one and zoom feels exponential. A small exponent dampens
    // the raw scale so a typical pinch covers a comfortable zoom range
    // instead of snapping straight to min/max.
    const zoomDamping = 0.6;
    final dampedScale = math.pow(details.scale, zoomDamping).toDouble();
    final maxView = math.max(durationSec, _minViewSeconds);
    final newView = (startView / dampedScale).clamp(_minViewSeconds, maxView);

    // `focalPointDelta` is per-frame in pixels, so we *do* integrate it
    // into the running center. Convert through the current view width so
    // panning speed feels right at any zoom level.
    final secPerPixel = newView / box.size.width;
    final newCenter =
        (startCenter - details.focalPointDelta.dx * secPerPixel)
            .clamp(0.0, durationSec)
            .toDouble();

    setState(() {
      _viewSeconds = newView;
      _pannedCenterSec = newCenter;
      // Only the pan anchor is updated each frame — the zoom anchor
      // stays put for the whole gesture (see comment above).
      _scaleStartCenterSec = newCenter;
    });
    _requestVisibleSpectrogram();
  }

  void _requestVisibleSpectrogram({bool force = false}) {
    final callback = widget.onViewportChanged;
    if (callback == null) return;
    final absoluteCenterSec = widget.timelineOffsetSec + _viewCenterSec;
    final centerDelta =
        _lastRequestedCenterSec == null
            ? double.infinity
            : (absoluteCenterSec - _lastRequestedCenterSec!).abs();
    final viewDelta =
        _lastRequestedViewSeconds == null
            ? double.infinity
            : (_viewSeconds - _lastRequestedViewSeconds!).abs();
    // Zoom changes scale relatively, so use a ratio against the last
    // requested view: tiny absolute deltas at high zoom should still
    // trigger a refresh, while small jitter at coarse zoom should not.
    final viewRatio =
        _lastRequestedViewSeconds == null || _lastRequestedViewSeconds! <= 0
            ? double.infinity
            : viewDelta / _lastRequestedViewSeconds!;
    if (!force &&
        centerDelta < _viewSeconds / 4 &&
        viewDelta < 0.25 &&
        viewRatio < 0.1) {
      return;
    }
    _lastRequestedCenterSec = absoluteCenterSec;
    _lastRequestedViewSeconds = _viewSeconds;
    callback(absoluteCenterSec, _viewSeconds);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Review Spectrogram Painter
// ═════════════════════════════════════════════════════════════════════════════

/// Viewport-blit painter for the pre-computed spectrogram image.
///
/// Derives pixels-per-second from `imageWidth / durationSec` so the
/// spectrogram always spans exactly the player duration.  No sample-rate
/// dependency — the image is simply stretched to fit the timeline.
class _ReviewSpectrogramPainter extends CustomPainter {
  _ReviewSpectrogramPainter({
    required this.spectrogramImage,
    required this.spectrogramChunks,
    required this.centerSec,
    required this.durationSec,
    required this.timelineOffsetSec,
    required this.viewSeconds,
    required this.colorScheme,
    required this.filterQuality,
    required this.quality,
    required this.session,
    required this.tsMode,
  });

  final ui.Image? spectrogramImage;
  final List<_SpectrogramChunk> spectrogramChunks;
  final double centerSec;
  final double durationSec;
  final double timelineOffsetSec;
  final double viewSeconds;
  final ColorScheme colorScheme;
  final FilterQuality filterQuality;
  final String quality;
  final LiveSession? session;
  final TimestampDisplayMode tsMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationSec <= 0) return;

    final startSec = centerSec - viewSeconds / 2;
    final endSec = centerSec + viewSeconds / 2;
    final absoluteStartSec = timelineOffsetSec + startSec;
    final absoluteEndSec = timelineOffsetSec + endSec;

    final img = spectrogramImage;
    if (img != null) {
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();

      // Derive pixel mapping from image width and player duration.
      final pxPerSec = imgW / durationSec;

      // Convert time to image pixel x.
      final srcX1 = (startSec * pxPerSec).clamp(0.0, imgW);
      final srcX2 = (endSec * pxPerSec).clamp(0.0, imgW);

      // Destination x: offset when the view extends before/after the image.
      final dstX1 = startSec < 0 ? (-startSec / viewSeconds * size.width) : 0.0;
      final dstX2 =
          endSec > durationSec
              ? size.width - ((endSec - durationSec) / viewSeconds * size.width)
              : size.width;

      if (srcX2 > srcX1 && dstX2 > dstX1) {
        canvas.drawImageRect(
          img,
          Rect.fromLTRB(srcX1, 0, srcX2, imgH),
          Rect.fromLTRB(dstX1, 0, dstX2, size.height),
          Paint()..filterQuality = filterQuality,
        );
      }
    }

    const targetSampleRate = 32000;

    for (final chunk in spectrogramChunks) {
      final chunkW = chunk.image.width.toDouble();
      final chunkH = chunk.image.height.toDouble();

      final overlapStart = math.max(absoluteStartSec, chunk.startSec);
      final overlapEnd = math.min(absoluteEndSec, chunk.endSec);
      if (overlapEnd <= overlapStart) continue;

      final srcX1 = ((overlapStart - chunk.startSec) *
              targetSampleRate /
              chunk.hop)
          .clamp(0.0, chunkW);
      final srcX2 = ((overlapEnd - chunk.startSec) *
              targetSampleRate /
              chunk.hop)
          .clamp(0.0, chunkW);

      final dstX1 =
          (overlapStart - absoluteStartSec) / viewSeconds * size.width;
      final dstX2 = (overlapEnd - absoluteStartSec) / viewSeconds * size.width;
      if (srcX2 <= srcX1 || dstX2 <= dstX1) continue;

      canvas.drawImageRect(
        chunk.image,
        Rect.fromLTRB(srcX1, 0, srcX2, chunkH),
        Rect.fromLTRB(dstX1, 0, dstX2, size.height),
        Paint()..filterQuality = filterQuality,
      );
    }

    // ── Playhead (fixed at center) ────────────────────────────────────
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );

    // ── Time labels ───────────────────────────────────────────────────
    final pxPerSecScreen = size.width / viewSeconds;
    final textStyle = TextStyle(
      color: Colors.white.withAlpha(180),
      fontSize: 9,
    );
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    // Step labels every ~2s at default zoom; tighten/loosen with zoom so
    // we never crowd the axis at high zoom or hide it at low zoom.
    final labelStepSec = _niceLabelStep(viewSeconds);
    final firstLabel = ((startSec / labelStepSec).ceil() * labelStepSec);
    for (var t = firstLabel; t < endSec; t += labelStepSec) {
      if (t < 0) continue;
      final x = (t - startSec) * pxPerSecScreen;
      if (x < 0 || x > size.width - 30) continue;
      tp.text = TextSpan(text: _fmtSec(t), style: textStyle);
      tp.layout();
      tp.paint(canvas, Offset(x + 2, size.height - tp.height - 2));
      canvas.drawLine(
        Offset(x, size.height - 2),
        Offset(x, size.height),
        Paint()..color = Colors.white.withAlpha(60),
      );
    }
  }

  String _fmtSec(double sec) {
    if (tsMode == TimestampDisplayMode.absolute && session != null) {
      final absoluteTime = session!.relativeToAbsolute(timelineOffsetSec + sec);
      final h = absoluteTime.toLocal().hour.toString().padLeft(2, '0');
      final m = absoluteTime.toLocal().minute.toString().padLeft(2, '0');
      final s = absoluteTime.toLocal().second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Pick a label cadence that keeps ~5 ticks across the viewport.
  static double _niceLabelStep(double viewSeconds) {
    const targetTicks = 5;
    final raw = viewSeconds / targetTicks;
    for (final step in const [0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 30, 60]) {
      if (raw <= step) return step.toDouble();
    }
    return 60.0;
  }

  @override
  bool shouldRepaint(covariant _ReviewSpectrogramPainter old) {
    return old.centerSec != centerSec ||
        old.durationSec != durationSec ||
        old.timelineOffsetSec != timelineOffsetSec ||
        old.viewSeconds != viewSeconds ||
        old.quality != quality ||
        old.tsMode != tsMode ||
        !identical(old.spectrogramImage, spectrogramImage) ||
        !identical(old.spectrogramChunks, spectrogramChunks) ||
        old.spectrogramChunks.length != spectrogramChunks.length;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Play/Pause Button Overlay
// ═════════════════════════════════════════════════════════════════════════════

/// Semi-transparent play/pause button overlaid on the spectrogram strip.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onToggle});

  final bool isPlaying;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isPlaying ? AppIcons.pause : AppIcons.playArrow,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Species Tile — Expandable row for one species
// ═════════════════════════════════════════════════════════════════════════════

class _SpeciesTile extends ConsumerStatefulWidget {
  const _SpeciesTile({
    super.key,
    required this.group,
    required this.session,
    required this.isExpanded,
    required this.positionNotifier,
    required this.isPlaying,
    required this.onToggleExpand,
    required this.onSpeciesInfo,
    required this.onSeekCluster,
    required this.onDeleteCluster,
    required this.onDeleteSpecies,
    required this.onReplaceCluster,
    required this.onToggleConfirmCluster,
    required this.onShareCluster,
    required this.onEditNoteCluster,
    required this.onEditVoiceMemoCluster,
    required this.onDeleteVoiceMemoCluster,
    this.activeCluster,
    this.onPause,
    this.clipOffsetSec = 0.0,
    this.windowSec = 3,
    this.isSurvey = false,
    this.audioAvailable = false,
    this.onShowOnMap,
  });

  final _SpeciesGroup group;
  final LiveSession session;
  final bool isExpanded;
  final ValueNotifier<Duration> positionNotifier;
  final bool isPlaying;

  /// Cluster currently being played via a per-detection clip player
  /// (used in survey review where there is no full recording). Matched
  /// by identity to highlight the active row.
  final _DetectionCluster? activeCluster;

  /// Offset (in seconds) of the loaded audio clip relative to the
  /// session start. Detection-only mode loads short clips; this lets
  /// the tile map detection timestamps into clip-relative coordinates.
  final double clipOffsetSec;

  /// Inference window duration (seconds) — used to extend each
  /// detection's active interval so a cluster stays highlighted while
  /// its analysis window is still being heard.
  final int windowSec;
  final bool isSurvey;
  final bool audioAvailable;
  final VoidCallback onToggleExpand;
  final VoidCallback onSpeciesInfo;
  final ValueChanged<_DetectionCluster> onSeekCluster;
  final ValueChanged<_DetectionCluster> onDeleteCluster;
  final VoidCallback onDeleteSpecies;
  final ValueChanged<_DetectionCluster> onReplaceCluster;

  /// Toggle the confirmed state of every record in a cluster.
  final ValueChanged<_DetectionCluster> onToggleConfirmCluster;

  /// Share the first record of a cluster via the platform share sheet.
  /// Wired up from the cluster row's long-press context menu (and any
  /// future per-detection share entry points).
  final ValueChanged<_DetectionCluster> onShareCluster;

  /// Open the note editor for a cluster (edits the cluster's first
  /// record, since a cluster represents one continuous detection of
  /// the same species and the user typically wants one note per row).
  final ValueChanged<_DetectionCluster> onEditNoteCluster;

  /// Open the voice-memo recorder for a cluster (also edits the
  /// cluster's first record).
  final ValueChanged<_DetectionCluster> onEditVoiceMemoCluster;

  /// Delete the voice memo attached to the cluster's first record.
  final ValueChanged<_DetectionCluster> onDeleteVoiceMemoCluster;
  final ValueChanged<DetectionRecord>? onShowOnMap;

  /// Called when the user taps the play affordance on a row that is
  /// currently being played (i.e. [isActive] is true). When `null`, the
  /// active row falls back to re-seeking, preserving the old behavior.
  final VoidCallback? onPause;

  @override
  ConsumerState<_SpeciesTile> createState() => _SpeciesTileState();
}

class _SpeciesActiveState {
  final bool isActive;
  final int activeClusterIndex;

  const _SpeciesActiveState({
    required this.isActive,
    required this.activeClusterIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpeciesActiveState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          activeClusterIndex == other.activeClusterIndex;

  @override
  int get hashCode => isActive.hashCode ^ activeClusterIndex.hashCode;
}

class _SpeciesTileState extends ConsumerState<_SpeciesTile> {
  late _SpeciesActiveState _activeState;

  @override
  void initState() {
    super.initState();
    _activeState = _checkActiveState(widget.positionNotifier.value);
    widget.positionNotifier.addListener(_onPositionChanged);
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(_SpeciesTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positionNotifier != oldWidget.positionNotifier ||
        widget.group != oldWidget.group ||
        widget.isPlaying != oldWidget.isPlaying ||
        widget.activeCluster != oldWidget.activeCluster) {
      oldWidget.positionNotifier.removeListener(_onPositionChanged);
      widget.positionNotifier.addListener(_onPositionChanged);
      _activeState = _checkActiveState(widget.positionNotifier.value);
    }
  }

  void _onPositionChanged() {
    if (!mounted) return;
    final newState = _checkActiveState(widget.positionNotifier.value);
    if (newState != _activeState) {
      setState(() {
        _activeState = newState;
      });
    }
  }

  _SpeciesActiveState _checkActiveState(Duration position) {
    // 1. Is species active?
    bool speciesActive = false;
    if (widget.isPlaying) {
      final clipOffset = Duration(
        microseconds: (widget.clipOffsetSec * 1e6).round(),
      );
      for (final r in widget.group.allRecords) {
        final relSec = widget.session.absoluteToRelative(r.timestamp);
        final rel = Duration(microseconds: (relSec * 1e6).round()) - clipOffset;
        final detEnd =
            r.endTimestamp != null
                ? Duration(
                      microseconds:
                          (widget.session.absoluteToRelative(r.endTimestamp!) *
                                  1e6)
                              .round(),
                    ) -
                    clipOffset
                : rel + Duration(seconds: widget.windowSec);
        if (position >= rel && position <= detEnd) {
          speciesActive = true;
          break;
        }
      }
    }

    // 2. Active cluster index
    int activeClusterIndex = -1;
    if (widget.activeCluster != null) {
      activeClusterIndex = widget.group.clusters.indexOf(widget.activeCluster!);
    } else if (widget.isPlaying) {
      for (int i = 0; i < widget.group.clusters.length; i++) {
        final cluster = widget.group.clusters[i];
        bool clusterActive = false;
        for (final r in cluster.records) {
          final startSec =
              widget.session.absoluteToRelative(r.timestamp) -
              widget.clipOffsetSec;
          final endSec =
              r.endTimestamp != null
                  ? widget.session.absoluteToRelative(r.endTimestamp!) -
                      widget.clipOffsetSec
                  : startSec + widget.windowSec;
          final posSec = position.inMicroseconds / 1e6;
          if (posSec >= startSec && posSec <= endSec) {
            clusterActive = true;
            break;
          }
        }
        if (clusterActive) {
          activeClusterIndex = i;
          break;
        }
      }
    }

    return _SpeciesActiveState(
      isActive: speciesActive,
      activeClusterIndex: activeClusterIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final showSciNames = ref.watch(showSciNamesProvider);
    final tsMode = TimestampDisplayMode.fromString(
      ref.watch(timestampDisplayModeProvider),
    );
    final tsShowSeconds = ref.watch(timestampShowSecondsProvider);

    final displayName =
        taxonomyAsync.value
            ?.lookup(widget.group.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        widget.group.commonName;

    // Render the per-cluster time using the user's selected mode.
    // Relative mode subtracts the current clip offset so that the
    // displayed offset stays aligned with the spectrogram playhead
    // after the audio has been cropped; absolute mode is unaffected
    // since wall-clock time is independent of the trim.
    final clipOffsetDur = Duration(
      microseconds: (widget.clipOffsetSec * 1e6).round(),
    );
    final offsetStr = formatDetectionTime(
      widget.group.firstTimestamp,
      widget.session.startTime,
      tsMode,
      absoluteToRelative: widget.session.absoluteToRelative,
      clipOffset: clipOffsetDur,
      showSeconds: tsShowSeconds,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color:
            _activeState.isActive
                ? theme.colorScheme.primaryContainer.withAlpha(90)
                : Colors.transparent,
        border:
            _activeState.isActive
                ? Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                )
                : null,
      ),
      child: Column(
        children: [
          // ── Main species row ───────────────────────────────
          Dismissible(
            key: ValueKey('species-${widget.group.scientificName}'),
            direction: DismissDirection.horizontal,
            background: _swipeSpeciesBackground(theme, alignLeft: true),
            secondaryBackground: _swipeSpeciesBackground(
              theme,
              alignLeft: false,
            ),
            onDismissed: (_) => widget.onDeleteSpecies(),
            child: InkWell(
              onTap: widget.onSpeciesInfo,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Seek to the first cluster that actually has audio (or
                    // fall back to the first cluster when whole-session audio
                    // is available). The previous logic only checked the
                    // first cluster, so the play button vanished whenever the
                    // earliest detection happened to lack a clip — even if
                    // every later cluster had one.
                    // When the species tile is currently being played and a
                    // pause callback is wired up, the same button doubles as a
                    // pause control so users can cancel playback.
                    if (widget.audioAvailable ||
                        widget.group.clusters.any((c) => c.hasAudioClip))
                      InkWell(
                        onTap:
                            () =>
                                _activeState.isActive && widget.onPause != null
                                    ? widget.onPause!()
                                    : widget.onSeekCluster(
                                      widget.group.clusters.firstWhere(
                                        (c) => c.hasAudioClip,
                                        orElse:
                                            () => widget.group.clusters.first,
                                      ),
                                    ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _activeState.isActive && widget.onPause != null
                                    ? AppIcons.pauseRounded
                                    : AppIcons.playArrowRounded,
                                size: 24,
                                color: theme.colorScheme.primary,
                              ),
                              Text(
                                offsetStr,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Text(
                          offsetStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // Species thumbnail. Uses the bundled image's 3:2 ratio
                    // so BoxFit.cover never has to crop the photo. Shortcut
                    // is now handled by tapping the entire row.
                    SizedBox(
                      width: 48,
                      height: 32,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          taxonomyAsync.value?.assetImagePath(
                                widget.group.scientificName,
                              ) ??
                              'assets/images/dummy_species.png',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (a, b, c) => Image.asset(
                                'assets/images/dummy_species.png',
                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Species info.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.group.allRecords.any(
                                (r) => r.isConfirmed,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    AppIcons.checkCircle,
                                    size: 14,
                                    color:
                                        AppSemanticColors.of(context).success,
                                  ),
                                ),
                              if (widget.group.allRecords.any(
                                (r) =>
                                    r.source == DetectionSource.manual ||
                                    r.source == DetectionSource.manualGlobal ||
                                    r.source == DetectionSource.userSpecified,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Tooltip(
                                    message:
                                        AppLocalizations.of(
                                          context,
                                        )!.detectionSourceManual,
                                    child: Icon(
                                      AppIcons.editNote,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              if (widget.group.totalCount > 1)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '×${widget.group.totalCount}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (showSciNames)
                                Expanded(
                                  child: Text(
                                    widget.group.scientificName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurface
                                          .withAlpha(153),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (!showSciNames) const Spacer(),
                              const SizedBox(width: 8),
                              Text(
                                widget.group.bestConfidencePercent,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _confidenceColor(
                                    widget.group.bestConfidence,
                                    theme,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Expand chevron interactive area. Covering the entire
                    // right portion of the card with a generous tap target.
                    Tooltip(
                      message:
                          widget.isExpanded
                              ? l10n.sessionLibraryCollapse
                              : l10n.sessionLibraryExpand,
                      child: InkWell(
                        onTap: widget.onToggleExpand,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 56,
                            minHeight: 48,
                          ),
                          alignment: Alignment.center,
                          child: AnimatedRotation(
                            turns: widget.isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              AppIcons.expandMore,
                              size: 24,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded cluster list ─────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              // Indent the detection rows so the hierarchical relationship
              // to the species card above is visually emphasized. The
              // inset roughly aligns the play column with the right edge
              // of the species thumbnail in the parent card.
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Column(
                children: [
                  for (var i = 0; i < widget.group.clusters.length; i++)
                    _ClusterRow(
                      cluster: widget.group.clusters[i],
                      session: widget.session,
                      clipOffsetSec: widget.clipOffsetSec,
                      windowSec: widget.windowSec,
                      isActive: _activeState.activeClusterIndex == i,
                      onSeek:
                          () => widget.onSeekCluster(widget.group.clusters[i]),
                      onPause: widget.onPause,
                      onDelete:
                          () =>
                              widget.onDeleteCluster(widget.group.clusters[i]),
                      onDeleteSpecies: widget.onDeleteSpecies,
                      onReplace:
                          () =>
                              widget.onReplaceCluster(widget.group.clusters[i]),
                      onToggleConfirm:
                          () => widget.onToggleConfirmCluster(
                            widget.group.clusters[i],
                          ),
                      onShare:
                          () => widget.onShareCluster(widget.group.clusters[i]),
                      onEditNote:
                          () => widget.onEditNoteCluster(
                            widget.group.clusters[i],
                          ),
                      onEditVoiceMemo:
                          () => widget.onEditVoiceMemoCluster(
                            widget.group.clusters[i],
                          ),
                      onDeleteVoiceMemo:
                          () => widget.onDeleteVoiceMemoCluster(
                            widget.group.clusters[i],
                          ),
                      isSurvey: widget.isSurvey,
                      audioAvailable: widget.audioAvailable,
                      onShowOnMap:
                          widget.onShowOnMap != null
                              ? () => widget.onShowOnMap!(
                                widget.group.clusters[i].records.first,
                              )
                              : null,
                    ),
                ],
              ),
            ),
            crossFadeState:
                widget.isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          const Divider(height: 1, indent: 60),
        ],
      ),
    );
  }

  Color _confidenceColor(double confidence, ThemeData theme) {
    final colors = theme.extension<ScoreColors>() ?? ScoreColors.light;
    return colors.forScore(confidence);
  }

  /// Background reveal for swipe-to-delete on the species header. Uses
  /// the sweep icon to mirror the `Delete species` overflow entry and
  /// distinguish a species-wide swipe from the per-detection delete on
  /// cluster rows below it.
  Widget _swipeSpeciesBackground(ThemeData theme, {required bool alignLeft}) {
    final color = theme.colorScheme.error;
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color.withAlpha(40)),
      child: Icon(AppIcons.deleteSweep, color: color),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Cluster Row — One time-span cluster within an expanded species
// ═════════════════════════════════════════════════════════════════════════════

class _ClusterRow extends ConsumerWidget {
  const _ClusterRow({
    required this.cluster,
    required this.session,
    required this.onSeek,
    required this.onDelete,
    required this.onDeleteSpecies,
    required this.onReplace,
    required this.onToggleConfirm,
    required this.onShare,
    required this.onEditNote,
    required this.onEditVoiceMemo,
    required this.onDeleteVoiceMemo,
    this.onPause,
    this.clipOffsetSec = 0.0,
    this.windowSec = 3,
    this.isActive = false,
    this.isSurvey = false,
    this.audioAvailable = false,
    this.onShowOnMap,
  });

  final _DetectionCluster cluster;
  final LiveSession session;
  final VoidCallback onSeek;
  final VoidCallback onDelete;
  final VoidCallback onDeleteSpecies;
  final VoidCallback onReplace;

  /// Toggles the confirmed state of every record in this cluster. The
  /// host screen owns the actual mutation and persistence; the row only
  /// reports user intent so it stays a pure presentational widget.
  final VoidCallback onToggleConfirm;

  /// Shares this cluster's representative detection via the platform
  /// share sheet. Surfaced through a long-press context menu on the row
  /// so we don't add yet another inline icon to the trailing strip.
  final VoidCallback onShare;

  /// Opens the note editor for this cluster's first record.
  final VoidCallback onEditNote;

  /// Opens the voice-memo recorder for this cluster's first record.
  final VoidCallback onEditVoiceMemo;

  /// Removes the voice memo from this cluster's first record.
  final VoidCallback onDeleteVoiceMemo;

  /// Pause callback used when this row is currently being played. When
  /// `null`, an active row continues to behave like a re-seek.
  final VoidCallback? onPause;
  final double clipOffsetSec;
  final int windowSec;
  final bool isActive;
  final bool isSurvey;
  final bool audioAvailable;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tsMode = TimestampDisplayMode.fromString(
      ref.watch(timestampDisplayModeProvider),
    );
    final tsShowSeconds = ref.watch(timestampShowSecondsProvider);
    final clipOffsetDur = Duration(microseconds: (clipOffsetSec * 1e6).round());
    // Prefer the recorded continuous-detection end. Fall back to the
    // last record's analysis-window end when [endTimestamp] is missing
    // (legacy sessions or in-progress records).
    final lastRecord = cluster.records.last;
    final lastEnd =
        lastRecord.endTimestamp ??
        lastRecord.timestamp.add(Duration(seconds: windowSec));
    // Always show the full span (start – end) so users can see the
    // duration of continuous detections at a glance. For very short
    // detections where the formatted strings would be identical, fall
    // back to a single timestamp to keep the row compact.
    final startStr = formatDetectionTime(
      cluster.firstTimestamp,
      session.startTime,
      tsMode,
      absoluteToRelative: session.absoluteToRelative,
      clipOffset: clipOffsetDur,
      showSeconds: tsShowSeconds,
    );
    final endStr = formatDetectionTime(
      lastEnd,
      session.startTime,
      tsMode,
      absoluteToRelative: session.absoluteToRelative,
      clipOffset: clipOffsetDur,
      showSeconds: tsShowSeconds,
    );
    final timeStr = startStr == endStr ? startStr : '$startStr \u2013 $endStr';
    final l10n = AppLocalizations.of(context)!;
    final confirmed = cluster.records.any((r) => r.isConfirmed);
    // A cluster is "manual" when every record was added by hand. We
    // surface that by replacing the play button with the same edit-note
    // glyph already shown on species headers, so reviewers can tell at
    // a glance which rows came from a tap rather than the model.
    final isManual = cluster.records.every(
      (r) =>
          r.source == DetectionSource.manual ||
          r.source == DetectionSource.manualGlobal ||
          r.source == DetectionSource.userSpecified,
    );

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color:
            isActive
                ? theme.colorScheme.primary.withAlpha(28)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            if (isManual)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Tooltip(
                  message: l10n.detectionSourceManual,
                  child: Icon(
                    AppIcons.editNote,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            else if (audioAvailable || cluster.hasAudioClip)
              InkWell(
                onTap: isActive && onPause != null ? onPause : onSeek,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isActive
                        ? (onPause != null
                            ? AppIcons.pauseRounded
                            : AppIcons.graphicEq)
                        : AppIcons.playArrowRounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            else
              const SizedBox(width: 48),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                timeStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(180),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (cluster.count > 1)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '×${cluster.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ),
            Text(
              cluster.bestConfidencePercent,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(width: 4),
            if (isSurvey && onShowOnMap != null)
              InkWell(
                onTap: onShowOnMap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    AppIcons.map,
                    size: 24,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ),
            Tooltip(
              message:
                  confirmed
                      ? l10n.detectionUnconfirmTooltip
                      : l10n.detectionConfirmTooltip,
              child: InkWell(
                onTap: onToggleConfirm,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    confirmed
                        ? AppIcons.checkCircle
                        : AppIcons.checkCircleOutline,
                    size: 24,
                    color:
                        confirmed
                            ? AppSemanticColors.of(context).success
                            : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ),
            ),
            if (cluster.records.first.hasNote)
              Tooltip(
                message:
                    cluster.records.first.note ?? l10n.detectionNoteTooltip,
                child: InkWell(
                  onTap: onEditNote,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      AppIcons.stickyNote2,
                      size: 22,
                      color: theme.colorScheme.primary.withAlpha(180),
                    ),
                  ),
                ),
              ),
            if (cluster.records.first.hasVoiceMemo)
              Tooltip(
                message: l10n.detectionVoiceMemoTooltip,
                child: InkWell(
                  onTap: onEditVoiceMemo,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      AppIcons.mic,
                      size: 22,
                      color: theme.colorScheme.primary.withAlpha(180),
                    ),
                  ),
                ),
              ),
            DetectionActionsOverflow(
              actions: DetectionActions(
                onShare: onShare,
                onDelete: onDelete,
                onDeleteSpecies: onDeleteSpecies,
                onReplace: onReplace,
                onEditNote: onEditNote,
                hasNote: cluster.records.first.hasNote,
                onEditVoiceMemo: onEditVoiceMemo,
                onDeleteVoiceMemo: onDeleteVoiceMemo,
                hasVoiceMemo: cluster.records.first.hasVoiceMemo,
              ),
              iconColor: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ],
        ),
      ),
    );

    // Wrap in Dismissible so horizontal swipes are shortcuts for the
    // two destructive/structural actions: swipe right (start→end)
    // deletes the cluster, swipe left (end→start) opens the replace
    // overlay. The undo SnackBar shown by the host covers misfires for
    // delete, so we omit the modal confirm dialog entirely. Replace
    // uses confirmDismiss to keep the row in place while the overlay
    // opens.
    final firstRecord = cluster.records.first;
    final dismissKey = ValueKey(
      '${firstRecord.scientificName}-${cluster.firstTimestamp.microsecondsSinceEpoch}',
    );
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        theme,
        alignLeft: true,
        icon: AppIcons.deleteOutline,
        color: theme.colorScheme.error,
      ),
      secondaryBackground: _swipeBackground(
        theme,
        alignLeft: false,
        icon: AppIcons.swapHoriz,
        color: theme.colorScheme.primary,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onReplace();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: row,
    );
  }

  Widget _swipeBackground(
    ThemeData theme, {
    required bool alignLeft,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Add Species Overlay — Search and insert a manual detection
// ═════════════════════════════════════════════════════════════════════════════

/// Insertion mode chosen by the user when adding a manual species detection.
enum AddSpeciesInsertMode {
  /// Insert a single detection with confidence 1.0 at the session start.
  global,

  /// Insert at a specific playback timestamp.
  atTimestamp,

  /// Replace an existing detection.
  replace,
}

/// Full-screen overlay for searching and adding a species to the session.
///
/// Returns an [AddSpeciesResult] or null if canceled.
///
/// Reused by both the post-session review screen (where the user picks how to
/// insert relative to the playhead and may also replace an existing record)
/// and the live survey screen (where the mode is implicitly "now", the
/// segmented selector is hidden via [lockMode], and the result is fed
/// straight to [SurveyController.addManualDetection]).
class AddSpeciesOverlay extends ConsumerStatefulWidget {
  const AddSpeciesOverlay({
    super.key,
    required this.sessionStart,
    required this.positionSec,
    required this.existingDetections,
    this.initialMode,
    this.initialReplaceTarget,
    this.lockMode = false,
    this.titleOverride,
  });

  final DateTime sessionStart;
  final double positionSec;
  final List<DetectionRecord> existingDetections;
  final AddSpeciesInsertMode? initialMode;
  final DetectionRecord? initialReplaceTarget;

  /// When true, hide the segmented insert-mode selector and use
  /// [initialMode] as a fixed choice. Used by the live survey entry point
  /// where only "insert at now" makes sense.
  final bool lockMode;

  /// Optional override for the AppBar title (defaults to localized
  /// "Add species" / "Replace detection").
  final String? titleOverride;

  @override
  ConsumerState<AddSpeciesOverlay> createState() => _AddSpeciesOverlayState();
}

class AddSpeciesResult {
  AddSpeciesResult({
    required this.scientificName,
    required this.commonName,
    required this.mode,
    this.replaceRecord,
    this.userSpecified = false,
  });

  final String scientificName;
  final String commonName;
  final AddSpeciesInsertMode mode;
  final DetectionRecord? replaceRecord;

  /// True when the user typed a free-text label via the "Other
  /// (specify)" entry instead of picking a species from the taxonomy.
  /// Callers should map this to [DetectionSource.userSpecified] so the
  /// record is recognizable as a user-supplied label.
  final bool userSpecified;
}

class _AddSpeciesOverlayState extends ConsumerState<AddSpeciesOverlay> {
  final _searchController = TextEditingController();
  List<TaxonomySpecies> _results = [];
  late AddSpeciesInsertMode _mode;
  DetectionRecord? _replaceTarget;

  /// True when entered from "Replace this detection" on a specific cluster.
  /// In this case the mode and target are locked and the mode selector is
  /// hidden — the user is only choosing the replacement species.
  bool get _isLockedReplace =>
      widget.initialMode == AddSpeciesInsertMode.replace &&
      widget.initialReplaceTarget != null;

  /// True when the segmented insert-mode selector should be hidden,
  /// either because of a locked replace or an explicit `lockMode: true`.
  bool get _hideModeSelector => _isLockedReplace || widget.lockMode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? AddSpeciesInsertMode.atTimestamp;
    _replaceTarget = widget.initialReplaceTarget;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final svc = ref.read(taxonomyServiceProvider).value;
    if (svc == null) return;
    final geoScores = ref.read(geoScoresProvider).value;
    setState(() {
      if (query.trim().isEmpty) {
        _results = [];
        return;
      }
      // Service ranks by text relevance (prefix > word-prefix > substring) and
      // observation count. We then apply a soft geo bump: among results with
      // equal text-relevance, prefer species likely to occur at this location.
      final raw = svc.search(query, limit: 100);
      if (geoScores != null && geoScores.isNotEmpty) {
        // Stable sort: only re-order when one result has a meaningfully higher
        // geo score than another. Cap influence so a perfect text match is
        // never demoted by geography alone.
        final stable = List<TaxonomySpecies>.from(raw);
        for (var i = 1; i < stable.length; i++) {
          final cur = stable[i];
          final prev = stable[i - 1];
          final scoreCur = geoScores[cur.scientificName] ?? 0.0;
          final scorePrev = geoScores[prev.scientificName] ?? 0.0;
          if (scoreCur > 0.5 && scorePrev <= 0.05) {
            stable[i - 1] = cur;
            stable[i] = prev;
          }
        }
        _results = stable.take(40).toList();
      } else {
        _results = raw.take(40).toList();
      }
    });
  }

  void _selectSpecies(String sciName, String comName) {
    Navigator.of(context).pop(
      AddSpeciesResult(
        scientificName: sciName,
        commonName: comName,
        mode: _mode,
        replaceRecord:
            _mode == AddSpeciesInsertMode.replace ? _replaceTarget : null,
      ),
    );
  }

  /// Open a small text-entry dialog for the "Other (specify)" entry
  /// in the empty-state, then pop with [AddSpeciesResult.userSpecified]
  /// set so the host marks the new record's source accordingly.
  Future<void> _pickOther() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionOtherSpeciesDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.sessionOtherSpeciesHint,
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (typed == null || !mounted) return;
    final trimmed = typed.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(
      AddSpeciesResult(
        scientificName: '',
        commonName: trimmed,
        mode: _mode,
        replaceRecord:
            _mode == AddSpeciesInsertMode.replace ? _replaceTarget : null,
        userSpecified: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.titleOverride ??
              (_isLockedReplace
                  ? l10n.sessionReplaceDetection
                  : l10n.sessionAddSpecies),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: l10n.tooltipClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Replace-target banner (locked replace mode only) ──
          if (_isLockedReplace && _replaceTarget != null)
            _ReplaceTargetBanner(
              target: _replaceTarget!,
              speciesLocale: speciesLocale,
              taxonomy: taxonomyAsync.value,
            ),

          // ── Insert mode selector (add mode only) ──────────
          if (!_hideModeSelector)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SegmentedButton<AddSpeciesInsertMode>(
                segments: [
                  ButtonSegment(
                    value: AddSpeciesInsertMode.atTimestamp,
                    label: Text(l10n.sessionInsertAtTimestamp),
                    icon: const Icon(AppIcons.schedule, size: 18),
                  ),
                  ButtonSegment(
                    value: AddSpeciesInsertMode.global,
                    label: Text(l10n.sessionInsertGlobally),
                    icon: const Icon(AppIcons.public, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = s.first);
                },
              ),
            ),

          // ── Search field ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.sessionSearchSpecies,
                prefixIcon: const Icon(AppIcons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(AppIcons.clear),
                          tooltip: l10n.tooltipClearSearch,
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ── Results / empty state ─────────────────────────
          Expanded(
            child:
                _searchController.text.trim().isEmpty
                    ? _SearchEmptyState(
                      onPickUnknown:
                          () => _selectSpecies(
                            DetectionRecord.unknownSpeciesName,
                            DetectionRecord.unknownCommonName,
                          ),
                      onPickOther: _pickOther,
                    )
                    : _results.isEmpty
                    ? _NoResultsState(query: _searchController.text.trim())
                    : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder:
                          (a, b) =>
                              Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final sp = _results[index];
                        final locName = sp.commonNameForLocale(speciesLocale);
                        return _SpeciesResultTile(
                          species: sp,
                          displayName: locName,
                          onTap:
                              () => _selectSpecies(
                                sp.scientificName,
                                sp.commonName,
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// Banner shown at the top of the overlay in locked-replace mode, displaying
/// the detection that will be replaced.
class _ReplaceTargetBanner extends ConsumerWidget {
  const _ReplaceTargetBanner({
    required this.target,
    required this.speciesLocale,
    required this.taxonomy,
  });

  final DetectionRecord target;
  final String speciesLocale;
  final TaxonomyService? taxonomy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final showSciNames = ref.watch(showSciNamesProvider);
    final species = taxonomy?.lookup(target.scientificName);
    final locName =
        species?.commonNameForLocale(speciesLocale) ?? target.commonName;
    final imagePath =
        species?.assetImagePath ?? 'assets/images/dummy_species.png';

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder:
                  (a, b, c) => Container(
                    width: 56,
                    height: 56,
                    color: theme.colorScheme.surfaceContainerHigh,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sessionReplacingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (showSciNames)
                  Text(
                    target.scientificName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(
            AppIcons.arrowDownward,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Result tile for a species search hit. Shows the bundled thumbnail, the
/// localized common name, and the scientific name in italics.
class _SpeciesResultTile extends ConsumerWidget {
  const _SpeciesResultTile({
    required this.species,
    required this.displayName,
    required this.onTap,
  });

  final TaxonomySpecies species;
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showSciNames = ref.watch(showSciNamesProvider);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          species.assetImagePath,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder:
              (a, b, c) => Container(
                width: 48,
                height: 48,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  AppIcons.imageNotSupported,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        ),
      ),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle:
          showSciNames
              ? Text(
                species.scientificName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              )
              : null,
      onTap: onTap,
    );
  }
}

/// Empty state shown before the user has typed anything: gives a hint and
/// surfaces the "Unknown / Other" + "Other (specify)" quick actions. The
/// two are intentionally split: "Unknown" is a sentinel for "I heard
/// something but can't identify it," while "Other (specify)" lets the
/// user attach a free-text label (e.g. "dog", "frog", "helicopter") that
/// isn't a taxonomy species at all.
class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.onPickUnknown,
    required this.onPickOther,
  });

  final VoidCallback onPickUnknown;
  final VoidCallback onPickOther;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            l10n.sessionSearchHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            AppIcons.helpOutline,
            color: theme.colorScheme.tertiary,
          ),
          title: Text(l10n.sessionUnknownSpecies),
          subtitle: Text(
            DetectionRecord.unknownSpeciesName,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          onTap: onPickUnknown,
        ),
        ListTile(
          leading: Icon(AppIcons.editNote, color: theme.colorScheme.tertiary),
          title: Text(l10n.sessionOtherSpecies),
          subtitle: Text(
            l10n.sessionOtherSpeciesHint,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          onTap: onPickOther,
        ),
      ],
    );
  }
}

/// Empty state shown when the search returns no results.
class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.searchOff,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.sessionNoResultsFor(query),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Annotations Section
// ═════════════════════════════════════════════════════════════════════════════

/// Collapsible section listing session annotations with an add button.
class _AnnotationsSection extends StatefulWidget {
  const _AnnotationsSection({
    required this.annotations,
    required this.positionSec,
    required this.onAdd,
    required this.onDelete,
  });

  final List<SessionAnnotation> annotations;
  final double positionSec;
  final ValueChanged<SessionAnnotation> onAdd;
  final ValueChanged<int> onDelete;

  @override
  State<_AnnotationsSection> createState() => _AnnotationsSectionState();
}

class _AnnotationsSectionState extends State<_AnnotationsSection> {
  final _textController = TextEditingController();
  bool _atTimestamp = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(
      SessionAnnotation(
        text: text,
        createdAt: DateTime.now(),
        offsetInRecording: _atTimestamp ? widget.positionSec : null,
      ),
    );
    _textController.clear();
    setState(() => _atTimestamp = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.sessionAnnotations,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Existing annotations ────────────────────────────
        for (var i = 0; i < widget.annotations.length; i++)
          _AnnotationRow(
            annotation: widget.annotations[i],
            onDelete: () => widget.onDelete(i),
          ),

        // ── Add annotation ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: l10n.sessionAddAnnotation,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _atTimestamp ? AppIcons.schedule : AppIcons.public,
                      size: 20,
                      color:
                          _atTimestamp
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withAlpha(120),
                    ),
                    tooltip:
                        _atTimestamp
                            ? l10n.sessionInsertAtTimestamp
                            : l10n.sessionAnnotationGlobal,
                    onPressed:
                        () => setState(() => _atTimestamp = !_atTimestamp),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      AppIcons.send,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: l10n.tooltipSendAnnotation,
                    onPressed: _submit,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnnotationRow extends StatefulWidget {
  const _AnnotationRow({required this.annotation, required this.onDelete});

  final SessionAnnotation annotation;
  final VoidCallback onDelete;

  @override
  State<_AnnotationRow> createState() => _AnnotationRowState();
}

class _AnnotationRowState extends State<_AnnotationRow> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isPlaying = false;

  @override
  void dispose() {
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleMemo() async {
    final path = widget.annotation.voiceMemoPath;
    if (path == null) return;
    var player = _player;
    if (player == null) {
      player = AudioPlayer();
      _player = player;
      try {
        await player.setFilePath(path);
      } catch (_) {
        return;
      }
      _stateSub = player.playerStateStream.listen((s) {
        if (!mounted) return;
        final playing =
            s.playing && s.processingState != ProcessingState.completed;
        if (playing != _isPlaying) setState(() => _isPlaying = playing);
        if (s.processingState == ProcessingState.completed) {
          player!.seek(Duration.zero);
          player.pause();
        }
      });
    }
    if (player.playing) {
      await player.pause();
    } else {
      await player.seek(Duration.zero);
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final annotation = widget.annotation;

    String offsetLabel;
    if (annotation.offsetInRecording != null) {
      final m = annotation.offsetInRecording! ~/ 60;
      final s = (annotation.offsetInRecording! % 60).toInt();
      offsetLabel =
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      offsetLabel = l10n.sessionAnnotationGlobal;
    }

    final hasText = annotation.text.trim().isNotEmpty;
    final displayText =
        hasText ? annotation.text : l10n.sessionAnnotationVoiceMemoLabel;
    final textStyle =
        hasText
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withAlpha(160),
            );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              offsetLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (annotation.hasVoiceMemo)
            InkWell(
              onTap: _toggleMemo,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _isPlaying ? AppIcons.stopCircle : AppIcons.playCircleOutline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Expanded(child: Text(displayText, style: textStyle)),
          InkWell(
            onTap: widget.onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                AppIcons.deleteOutline,
                size: 16,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trim Handles — Overlay for recording start/end trimming
// ═════════════════════════════════════════════════════════════════════════════

/// Overlay painted on top of the spectrogram strip showing trim handles.
///
/// Users drag the left handle for trim-start and right handle for trim-end,
/// similar to video cropping in Google Photos.
class _TrimOverlay extends StatefulWidget {
  const _TrimOverlay({
    required this.durationSec,
    required this.initialStartSec,
    required this.initialEndSec,
    required this.onChanged,
  }) : visibleStartSec = 0,
       visibleEndSec = null;

  /// Variant that operates within a sub-window of the recording.
  ///
  /// Used for lazy-loaded long files where the full-file spectrogram
  /// thumbnail isn't available: the overlay is laid out on top of the
  /// live `_SpectrogramStrip`, and `visibleStartSec`/`visibleEndSec`
  /// describe the strip's currently painted window. Handle drags map
  /// pixel positions to absolute seconds inside that window and are
  /// clamped to it — to extend the trim outside the visible range the
  /// user exits trim mode, zooms/scrolls, and re-enters.
  const _TrimOverlay.windowed({
    required this.visibleStartSec,
    required double this.visibleEndSec,
    required this.initialStartSec,
    required this.initialEndSec,
    required this.onChanged,
  }) : durationSec = 0;

  final double durationSec;
  final double visibleStartSec;
  final double? visibleEndSec;
  final double initialStartSec;
  final double initialEndSec;
  final void Function(double startSec, double endSec) onChanged;

  bool get isWindowed => visibleEndSec != null;

  double get _windowStart => isWindowed ? visibleStartSec : 0.0;
  double get _windowEnd => isWindowed ? visibleEndSec! : durationSec;

  @override
  State<_TrimOverlay> createState() => _TrimOverlayState();
}

class _TrimOverlayState extends State<_TrimOverlay> {
  late double _startFrac;
  late double _endFrac;
  bool _draggingStart = false;
  bool _draggingEnd = false;

  double _secToFrac(double sec) {
    final span = widget._windowEnd - widget._windowStart;
    if (span <= 0) return 0.0;
    return ((sec - widget._windowStart) / span).clamp(0.0, 1.0);
  }

  double _fracToSec(double frac) {
    final span = widget._windowEnd - widget._windowStart;
    return widget._windowStart + frac * span;
  }

  @override
  void initState() {
    super.initState();
    _startFrac = _secToFrac(widget.initialStartSec);
    _endFrac = _secToFrac(widget.initialEndSec);
  }

  @override
  void didUpdateWidget(covariant _TrimOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the underlying window shifted (e.g. user scrolled the strip
    // before grabbing a handle), remap the handle positions so they
    // stay anchored to the same absolute seconds.
    if (oldWidget.visibleStartSec != widget.visibleStartSec ||
        oldWidget.visibleEndSec != widget.visibleEndSec ||
        oldWidget.durationSec != widget.durationSec) {
      final span = widget._windowEnd - widget._windowStart;
      if (span <= 0) {
        _startFrac = 0.0;
        _endFrac = 1.0;
      } else {
        _startFrac = _secToFrac(widget.initialStartSec);
        _endFrac = _secToFrac(widget.initialEndSec);
      }
    }
  }

  void _reportChange() {
    widget.onChanged(_fracToSec(_startFrac), _fracToSec(_endFrac));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final leftX = _startFrac * w;
        final rightX = _endFrac * w;

        return GestureDetector(
          onHorizontalDragStart: (d) {
            final x = d.localPosition.dx;
            // Decide which handle is closest.
            if ((x - leftX).abs() < (x - rightX).abs()) {
              _draggingStart = true;
              _draggingEnd = false;
            } else {
              _draggingStart = false;
              _draggingEnd = true;
            }
          },
          onHorizontalDragUpdate: (d) {
            setState(() {
              final frac = (d.localPosition.dx / w).clamp(0.0, 1.0);
              if (_draggingStart) {
                _startFrac = math.min(frac, _endFrac - 0.01);
              } else if (_draggingEnd) {
                _endFrac = math.max(frac, _startFrac + 0.01);
              }
            });
          },
          onHorizontalDragEnd: (_) {
            _draggingStart = false;
            _draggingEnd = false;
            _reportChange();
          },
          child: CustomPaint(
            painter: _TrimOverlayPainter(
              startFrac: _startFrac,
              endFrac: _endFrac,
              accentColor: theme.colorScheme.primary,
            ),
            size: Size(w, h),
          ),
        );
      },
    );
  }
}

class _TrimOverlayPainter extends CustomPainter {
  _TrimOverlayPainter({
    required this.startFrac,
    required this.endFrac,
    required this.accentColor,
  });

  final double startFrac;
  final double endFrac;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withAlpha(140);
    final handlePaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;

    // Dimmed regions outside the trim.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, startFrac * size.width, size.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(endFrac * size.width, 0, size.width, size.height),
      dimPaint,
    );

    // Top/bottom borders of the selected region.
    final borderPaint =
        Paint()
          ..color = accentColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(
        startFrac * size.width,
        0,
        endFrac * size.width,
        size.height,
      ),
      borderPaint,
    );

    // Left handle.
    const hw = 14.0;
    const hh = 32.0;
    final ly = (size.height - hh) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startFrac * size.width - hw / 2, ly, hw, hh),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    // Grip lines on left handle.
    final gripPaint =
        Paint()
          ..color = Colors.white.withAlpha(200)
          ..strokeWidth = 1.5;
    for (var i = -1; i <= 1; i++) {
      final cx = startFrac * size.width;
      final cy = size.height / 2 + i * 5.0;
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), gripPaint);
    }

    // Right handle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(endFrac * size.width - hw / 2, ly, hw, hh),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    for (var i = -1; i <= 1; i++) {
      final cx = endFrac * size.width;
      final cy = size.height / 2 + i * 5.0;
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), gripPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrimOverlayPainter old) =>
      old.startFrac != startFrac || old.endFrac != endFrac;
}

// ═════════════════════════════════════════════════════════════════════════════
// Zoomable Trim Spectrogram View
// ═════════════════════════════════════════════════════════════════════════════

/// Full-recording spectrogram with pinch-to-zoom, scroll, and trim handles.
///
/// Replaces the fixed-viewport spectrogram strip when trim mode is active.
/// At zoom=1 the entire recording fits on screen.  Pinch to zoom in for
/// precise handle placement.  Drag horizontally to scroll when zoomed.
class _TrimSpectrogramView extends StatefulWidget {
  const _TrimSpectrogramView({
    required this.spectrogramImage,
    required this.durationSec,
    required this.initialStartSec,
    required this.initialEndSec,
    required this.onChanged,
    this.quality = 'medium',
  });

  final ui.Image spectrogramImage;
  final double durationSec;
  final double initialStartSec;
  final double initialEndSec;
  final void Function(double startSec, double endSec) onChanged;
  final String quality;

  @override
  State<_TrimSpectrogramView> createState() => _TrimSpectrogramViewState();
}

class _TrimSpectrogramViewState extends State<_TrimSpectrogramView> {
  double _zoom = 1.0;
  double _scrollSec = 0.0;
  double _baseZoom = 1.0;
  Offset? _lastFocalPoint;
  late double _startSec;
  late double _endSec;
  String? _activeDrag; // 'start', 'end', or null for zoom/pan

  @override
  void initState() {
    super.initState();
    _startSec = widget.initialStartSec;
    _endSec = widget.initialEndSec;
  }

  double get _viewDurationSec => widget.durationSec / _zoom;

  double _secToX(double sec, double width) {
    return (sec - _scrollSec) / _viewDurationSec * width;
  }

  double _xToSec(double x, double width) {
    return _scrollSec + x / width * _viewDurationSec;
  }

  void _clampScroll() {
    final maxScroll = widget.durationSec - _viewDurationSec;
    _scrollSec = _scrollSec.clamp(0.0, math.max(0.0, maxScroll));
  }

  void _onScaleStart(ScaleStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    final startX = _secToX(_startSec, w);
    final endX = _secToX(_endSec, w);
    final touchX = details.localFocalPoint.dx;

    const handleThreshold = 28.0;
    final distToStart = (touchX - startX).abs();
    final distToEnd = (touchX - endX).abs();
    if (distToStart < handleThreshold && distToStart <= distToEnd) {
      _activeDrag = 'start';
    } else if (distToEnd < handleThreshold) {
      _activeDrag = 'end';
    } else {
      _activeDrag = null;
      _baseZoom = _zoom;
      _lastFocalPoint = details.localFocalPoint;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;

    if (_activeDrag != null) {
      final sec = _xToSec(
        details.localFocalPoint.dx,
        w,
      ).clamp(0.0, widget.durationSec);
      setState(() {
        if (_activeDrag == 'start') {
          _startSec = math.min(sec, _endSec - 0.5);
        } else {
          _endSec = math.max(sec, _startSec + 0.5);
        }
      });
    } else {
      setState(() {
        _zoom = (_baseZoom * details.scale).clamp(1.0, 20.0);
        final dx =
            details.localFocalPoint.dx -
            (_lastFocalPoint?.dx ?? details.localFocalPoint.dx);
        final secPerPx = _viewDurationSec / w;
        _scrollSec -= dx * secPerPx;
        _clampScroll();
        _lastFocalPoint = details.localFocalPoint;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_activeDrag != null) {
      widget.onChanged(_startSec, _endSec);
    }
    _activeDrag = null;
    _lastFocalPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Container(
        height: 150,
        color: Colors.black,
        child: CustomPaint(
          painter: _TrimSpectrogramPainter(
            spectrogramImage: widget.spectrogramImage,
            durationSec: widget.durationSec,
            scrollSec: _scrollSec,
            viewDurationSec: _viewDurationSec,
            trimStartSec: _startSec,
            trimEndSec: _endSec,
            accentColor: theme.colorScheme.primary,
            filterQuality: spectrogramFilterQualityFromString(widget.quality),
          ),
          size: const Size(double.infinity, 150),
        ),
      ),
    );
  }
}

class _TrimSpectrogramPainter extends CustomPainter {
  _TrimSpectrogramPainter({
    required this.spectrogramImage,
    required this.durationSec,
    required this.scrollSec,
    required this.viewDurationSec,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.accentColor,
    required this.filterQuality,
  });

  final ui.Image spectrogramImage;
  final double durationSec;
  final double scrollSec;
  final double viewDurationSec;
  final double trimStartSec;
  final double trimEndSec;
  final Color accentColor;
  final FilterQuality filterQuality;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationSec <= 0) return;
    final imgW = spectrogramImage.width.toDouble();
    final imgH = spectrogramImage.height.toDouble();
    final pxPerSec = imgW / durationSec;

    // Draw the visible portion of the spectrogram.
    final srcX1 = (scrollSec * pxPerSec).clamp(0.0, imgW);
    final srcX2 = ((scrollSec + viewDurationSec) * pxPerSec).clamp(0.0, imgW);
    if (srcX2 > srcX1) {
      canvas.drawImageRect(
        spectrogramImage,
        Rect.fromLTRB(srcX1, 0, srcX2, imgH),
        Rect.fromLTRB(0, 0, size.width, size.height),
        Paint()..filterQuality = filterQuality,
      );
    }

    // Dimmed regions outside the trim selection.
    final dimPaint = Paint()..color = Colors.black.withAlpha(140);
    final trimStartX =
        (trimStartSec - scrollSec) / viewDurationSec * size.width;
    final trimEndX = (trimEndSec - scrollSec) / viewDurationSec * size.width;

    if (trimStartX > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, trimStartX.clamp(0, size.width), size.height),
        dimPaint,
      );
    }
    if (trimEndX < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(
          trimEndX.clamp(0, size.width),
          0,
          size.width,
          size.height,
        ),
        dimPaint,
      );
    }

    // Border around the selected region.
    final borderPaint =
        Paint()
          ..color = accentColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(
        trimStartX.clamp(0, size.width),
        0,
        trimEndX.clamp(0, size.width),
        size.height,
      ),
      borderPaint,
    );

    // ── Trim handles ──────────────────────────────────────────────
    const hw = 14.0;
    const hh = 32.0;
    final handlePaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
    final gripPaint =
        Paint()
          ..color = Colors.white.withAlpha(200)
          ..strokeWidth = 1.5;
    for (final hx in [trimStartX, trimEndX]) {
      if (hx < -hw || hx > size.width + hw) continue;
      final ly = (size.height - hh) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hx - hw / 2, ly, hw, hh),
          const Radius.circular(4),
        ),
        handlePaint,
      );
      for (var i = -1; i <= 1; i++) {
        final cy = size.height / 2 + i * 5.0;
        canvas.drawLine(Offset(hx - 3, cy), Offset(hx + 3, cy), gripPaint);
      }
    }

    // ── Time labels ───────────────────────────────────────────────
    final textStyle = TextStyle(
      color: Colors.white.withAlpha(180),
      fontSize: 9,
    );
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    double interval = 2.0;
    if (viewDurationSec > 120) {
      interval = 30.0;
    } else if (viewDurationSec > 60) {
      interval = 10.0;
    } else if (viewDurationSec > 30) {
      interval = 5.0;
    }

    final firstLabel = ((scrollSec / interval).ceil() * interval);
    for (var t = firstLabel; t < scrollSec + viewDurationSec; t += interval) {
      final x = (t - scrollSec) / viewDurationSec * size.width;
      if (x < 0 || x > size.width - 30) continue;
      final m = t ~/ 60;
      final s = (t % 60).toInt();
      tp.text = TextSpan(
        text: '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        style: textStyle,
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 2, size.height - tp.height - 2));
      canvas.drawLine(
        Offset(x, size.height - 2),
        Offset(x, size.height),
        Paint()..color = Colors.white.withAlpha(60),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrimSpectrogramPainter old) => true;
}

// ═════════════════════════════════════════════════════════════════════════════
// Help Dialog
// ═════════════════════════════════════════════════════════════════════════════

/// Bottom sheet displaying help documentation for the session review screen.
class _SessionHelpSheet extends StatelessWidget {
  const _SessionHelpSheet({required this.showContinueSurvey});

  final bool showContinueSurvey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppHelpBottomSheet(
      title: l10n.sessionHelpTitle,
      initialChildSize: 0.72,
      sections: [
        AppHelpSection(
          icon: AppIcons.infoOutline,
          body: l10n.sessionHelpOverview,
        ),
        AppHelpSection(icon: AppIcons.close, body: l10n.sessionHelpTopBar),
        AppHelpSection(
          icon: AppIcons.addCircleOutline,
          body: l10n.sessionHelpAddSpecies,
        ),
        AppHelpSection(icon: AppIcons.undo, body: l10n.sessionHelpUndoRedo),
        AppHelpSection(
          icon: AppIcons.contentCut,
          body: l10n.sessionHelpTrimming,
        ),
        AppHelpSection(icon: AppIcons.save, body: l10n.sessionHelpSaveDiscard),
        if (showContinueSurvey)
          AppHelpSection(
            icon: AppIcons.playArrowRounded,
            body: l10n.sessionHelpContinueSurvey,
          ),
      ],
    );
  }
}
