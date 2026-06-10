// =============================================================================
// Point Count Setup Screen — Wizard for configuring a timed point-count survey
// =============================================================================
//
// A four-step setup wizard following standard point-count protocol:
//
//   1. **Duration & Context** — Select count duration (3–20 min), choose
//      location (GPS / Manual with map picker / Skip), and display date.
//   2. **Inference Parameters** — Tweak window duration, inference rate,
//      confidence threshold, and species filter mode for this session.
//      Defaults come from the global app settings.
//   3. **Field Tips** — Best-practice reminders (stable surface, avoid wind,
//      stay quiet, microphone placement, etc.).
//   4. **Ready** — Summary and explicit "Start Count" button.
//
// After the user presses Start, navigates to [PointCountLiveScreen] which
// runs the timed session with a countdown timer.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/map_picker_screen.dart';
import '../../shared/widgets/site_context_card.dart';
import '../../shared/widgets/weather_setup_card.dart';
import '../../shared/widgets/wizard_scaffold.dart';
import '../explore/explore_providers.dart';
import '../settings/settings_screen.dart';
import 'point_count_live_screen.dart';

/// Location choice for the point count setup.
enum _LocationChoice { gps, manual, skip }

/// Setup wizard for a timed point-count survey.
class PointCountSetupScreen extends ConsumerStatefulWidget {
  const PointCountSetupScreen({super.key});

  @override
  ConsumerState<PointCountSetupScreen> createState() =>
      _PointCountSetupScreenState();
}

class _PointCountSetupScreenState extends ConsumerState<PointCountSetupScreen>
    with WidgetsBindingObserver {
  int _step = 0;
  static const _totalSteps = 4;

  /// Available durations in minutes.
  static const _durations = [3, 5, 10, 15, 20];

  // Auto-retry GPS until a fix is acquired or we give up.
  static const _maxGpsAttempts = 5;
  static const _gpsRetryDelay = Duration(seconds: 5);
  // Reuse a recent fix instead of re-fetching when the wizard is reopened
  // shortly after a previous successful fix. The refresh button forces a
  // fresh read by passing `Duration.zero`.
  static const _gpsCacheMaxAge = Duration(minutes: 2);

  // ── Location state ──────────────────────────────────────────────────────
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  bool _gpsFetching = false;
  int _gpsAttempts = 0;
  int _gpsRequestSerial = 0;
  Timer? _gpsRetryTimer;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  // ── Identity fields ─────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _observerController = TextEditingController();

  // ── Inference parameters (overrides for this session only) ─────────────
  late int _windowDuration;
  late double _inferenceRate;
  late int _confidenceThreshold;
  late double _sensitivity;
  late String _speciesFilterMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pre-fill observer with the last value used.
    _observerController.text = ref.read(pointCountLastObserverProvider);
    // Seed parameter state from the global app defaults.
    _windowDuration = ref.read(windowDurationProvider);
    _inferenceRate = ref.read(inferenceRateProvider);
    _confidenceThreshold = ref.read(confidenceThresholdProvider);
    _sensitivity = ref.read(sensitivityProvider);
    _speciesFilterMode = ref.read(speciesFilterModeProvider);
    // Start fetching GPS location immediately. Reuse a recent fix if one
    // is still warm — closing and reopening the wizard within a couple of
    // minutes shouldn't burn another 10s waiting on the same fix.
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsRetryTimer?.cancel();
    _latController.dispose();
    _lonController.dispose();
    _nameController.dispose();
    _observerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _locationChoice == _LocationChoice.gps &&
        _latitude == null &&
        !_gpsFetching) {
      // Resuming with no fix yet — restart the auto-retry budget so a user
      // who came back from settings (or just stepped outdoors) gets another
      // round of attempts rather than the stale "Location unavailable" card.
      _fetchGpsLocation();
    }
  }

  /// Kick off (or restart) the GPS auto-retry loop.
  ///
  /// Pass [resetAttempts] `false` only from the retry timer — callers from
  /// the UI (initState, refresh button, location-mode toggle) should leave
  /// it as `true` so the attempt counter resets.
  ///
  /// Pass [forceFresh] `true` from the refresh button to bypass the
  /// service-level cache and re-read GPS hardware.
  Future<void> _fetchGpsLocation({
    bool resetAttempts = true,
    bool forceFresh = false,
  }) async {
    if (resetAttempts) {
      _gpsRetryTimer?.cancel();
      _gpsRetryTimer = null;
      _gpsAttempts = 0;
    }
    _gpsAttempts++;
    final serial = ++_gpsRequestSerial;
    if (!_gpsFetching) setState(() => _gpsFetching = true);
    try {
      final service = ref.read(locationServiceProvider);
      final location = await service.getCurrentLocation(
        maxAge: forceFresh ? Duration.zero : _gpsCacheMaxAge,
      );
      if (!mounted || serial != _gpsRequestSerial) return;
      if (location != null) {
        _gpsRetryTimer?.cancel();
        _gpsRetryTimer = null;
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _gpsFetching = false;
        });
        if (service.lastFetchUsedCachedFallback) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.gpsStaleWarning),
                duration: const Duration(seconds: 4),
              ),
            );
        }
        return;
      }
      _scheduleGpsRetryOrStop();
    } catch (_) {
      if (!mounted || serial != _gpsRequestSerial) return;
      _scheduleGpsRetryOrStop();
    }
  }

  void _scheduleGpsRetryOrStop() {
    if (!mounted ||
        _locationChoice != _LocationChoice.gps ||
        _gpsAttempts >= _maxGpsAttempts) {
      if (mounted) setState(() => _gpsFetching = false);
      return;
    }
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(_gpsRetryDelay, () {
      if (!mounted || _locationChoice != _LocationChoice.gps) return;
      _fetchGpsLocation(resetAttempts: false);
    });
  }

  void _cancelGpsAutoRetry() {
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;
    _gpsRequestSerial++;
    if (_gpsFetching && mounted) {
      setState(() => _gpsFetching = false);
    }
  }

  void _next() {
    // When leaving step 0, parse manual lat/lon if in manual mode.
    if (_step == 0 && _locationChoice == _LocationChoice.manual) {
      _latitude = double.tryParse(_latController.text)?.clamp(-90, 90);
      _longitude = double.tryParse(_lonController.text)?.clamp(-180, 180);
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _start() {
    final durationMin = ref.read(pointCountDurationProvider);
    final lat = _locationChoice == _LocationChoice.skip ? null : _latitude;
    final lon = _locationChoice == _LocationChoice.skip ? null : _longitude;
    final name = _nameController.text.trim();
    final observer = _observerController.text.trim();

    // Persist observer for next time.
    if (observer.isNotEmpty) {
      ref.read(pointCountLastObserverProvider.notifier).set(observer);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => PointCountLiveScreen(
              durationMinutes: durationMin,
              latitude: lat,
              longitude: lon,
              customName: name.isEmpty ? null : name,
              observerName: observer.isEmpty ? null : observer,
              windowDurationOverride: _windowDuration,
              inferenceRateOverride: _inferenceRate,
              confidenceThresholdOverride: _confidenceThreshold,
              speciesFilterModeOverride: _speciesFilterMode,
              sensitivityOverride: _sensitivity,
            ),
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.pointCountSetupHelpTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.timerRounded,
                body: l10n.pointCountSetupHelpSteps,
              ),
              AppHelpSection(
                icon: AppIcons.locationOnRounded,
                body: l10n.pointCountSetupHelpLocation,
              ),
              AppHelpSection(
                icon: AppIcons.playArrowRounded,
                body: l10n.pointCountSetupHelpStart,
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLastStep = _step == _totalSteps - 1;

    return WizardScaffold(
      title: l10n.pointCountSetupTitle,
      step: _step,
      totalSteps: _totalSteps,
      actions: [
        IconButton(
          icon: const Icon(AppIcons.helpOutlineRounded, size: 20),
          onPressed: _showHelp,
          tooltip: l10n.pointCountSetupHelpTitle,
        ),
        IconButton(
          icon: const Icon(AppIcons.tuneRounded, size: 20),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => const SettingsScreen(
                      settingsContext: SettingsContext.pointCount,
                    ),
              ),
            );
          },
          tooltip: l10n.settings,
        ),
      ],
      onBack: _back,
      onNext: isLastStep ? _start : _next,
      backLabel: _step == 0 ? l10n.cancel : l10n.pointCountBack,
      nextLabel: isLastStep ? l10n.pointCountStart : l10n.pointCountNext,
      nextIcon: isLastStep ? AppIcons.playArrowRounded : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          0 => _DurationStep(
            key: const ValueKey(0),
            durations: _durations,
            nameController: _nameController,
            observerController: _observerController,
            locationChoice: _locationChoice,
            latitude: _latitude,
            longitude: _longitude,
            gpsFetching: _gpsFetching,
            latController: _latController,
            lonController: _lonController,
            onLocationChoiceChanged: (c) {
              setState(() => _locationChoice = c);
              if (c == _LocationChoice.gps) {
                _fetchGpsLocation();
              } else {
                _cancelGpsAutoRetry();
              }
            },
            onFetchGps: () => _fetchGpsLocation(forceFresh: true),
            onMapPick: (lat, lon) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
              });
            },
          ),
          1 => _ParametersStep(
            key: const ValueKey(1),
            inferenceRate: _inferenceRate,
            confidenceThreshold: _confidenceThreshold,
            sensitivity: _sensitivity,
            speciesFilterMode: _speciesFilterMode,
            onInferenceRateChanged: (v) => setState(() => _inferenceRate = v),
            onConfidenceChanged:
                (v) => setState(() => _confidenceThreshold = v),
            onSensitivityChanged: (v) => setState(() => _sensitivity = v),
            onFilterModeChanged: (v) => setState(() => _speciesFilterMode = v),
          ),
          2 => _TipsStep(key: const ValueKey(2)),
          _ => _ReadyStep(
            key: const ValueKey(3),
            latitude: _latitude,
            longitude: _longitude,
          ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Duration & Context
// ─────────────────────────────────────────────────────────────────────────────

class _DurationStep extends ConsumerWidget {
  const _DurationStep({
    super.key,
    required this.durations,
    required this.nameController,
    required this.observerController,
    required this.locationChoice,
    required this.latitude,
    required this.longitude,
    required this.gpsFetching,
    required this.latController,
    required this.lonController,
    required this.onLocationChoiceChanged,
    required this.onFetchGps,
    required this.onMapPick,
  });

  final List<int> durations;
  final TextEditingController nameController;
  final TextEditingController observerController;
  final _LocationChoice locationChoice;
  final double? latitude;
  final double? longitude;
  final bool gpsFetching;
  final TextEditingController latController;
  final TextEditingController lonController;
  final void Function(_LocationChoice) onLocationChoiceChanged;
  final VoidCallback onFetchGps;
  final void Function(double lat, double lon) onMapPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(pointCountDurationProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),

        // Name & observer
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.pointCountName,
            hintText: l10n.pointCountNameHint,
            prefixIcon: const Icon(AppIcons.edit),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: observerController,
          decoration: InputDecoration(
            labelText: l10n.surveyObserverName,
            hintText: l10n.surveyObserverNameHint,
            prefixIcon: const Icon(AppIcons.personRounded),
          ),
        ),
        const SizedBox(height: 24),

        // Duration picker
        Text(
          l10n.pointCountDuration,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              durations.map((min) {
                final isSelected = min == selected;
                return ChoiceChip(
                  label: Text(l10n.pointCountDurationMinutes(min)),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(pointCountDurationProvider.notifier).set(min);
                  },
                );
              }).toList(),
        ),

        const SizedBox(height: 32),

        // Location & date
        Text(
          l10n.pointCountLocationDate,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Date row
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  AppIcons.calendarTodayRounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.yMMMMd().add_jm().format(DateTime.now()),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Location mode selector
        SegmentedButton<_LocationChoice>(
          segments: [
            ButtonSegment(
              value: _LocationChoice.gps,
              icon: const Icon(AppIcons.myLocation, size: 18),
              label: Text(l10n.pointCountLocationGps),
            ),
            ButtonSegment(
              value: _LocationChoice.manual,
              icon: const Icon(AppIcons.editLocationAlt, size: 18),
              label: Text(l10n.pointCountLocationManual),
            ),
            ButtonSegment(
              value: _LocationChoice.skip,
              icon: const Icon(AppIcons.locationOff, size: 18),
              label: Text(l10n.pointCountLocationSkip),
            ),
          ],
          selected: {locationChoice},
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            onLocationChoiceChanged(s.first);
          },
          showSelectedIcon: false,
        ),

        // ── GPS result ───────────────────────────────────────
        if (locationChoice == _LocationChoice.gps) ...[
          const SizedBox(height: 16),
          if (gpsFetching)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.pointCountLocationAcquiring,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (latitude != null && longitude != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.locationOnRounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${latitude!.toStringAsFixed(5)}, '
                        '${longitude!.toStringAsFixed(5)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onFetchGps,
                      icon: const Icon(AppIcons.refresh),
                      tooltip: l10n.pointCountLocationRefresh,
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.locationOffRounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pointCountLocationUnavailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onFetchGps,
                      icon: const Icon(AppIcons.refresh),
                      tooltip: l10n.pointCountLocationRefresh,
                    ),
                  ],
                ),
              ),
            ),
        ],

        // ── Manual input ─────────────────────────────────────
        if (locationChoice == _LocationChoice.manual) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.pointCountLatitude,
                    border: const OutlineInputBorder(),
                    hintText: '52.52',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.pointCountLongitude,
                    border: const OutlineInputBorder(),
                    hintText: '13.405',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute<LatLng>(
                  builder:
                      (_) => MapPickerScreen(
                        initialLat: double.tryParse(latController.text),
                        initialLon: double.tryParse(lonController.text),
                      ),
                ),
              );
              if (result != null) {
                latController.text = result.latitude.toStringAsFixed(5);
                lonController.text = result.longitude.toStringAsFixed(5);
                onMapPick(result.latitude, result.longitude);
              }
            },
            icon: const Icon(AppIcons.map, size: 18),
            label: Text(l10n.pointCountPickOnMap),
          ),
        ],

        // ── Skip note ────────────────────────────────────────
        if (locationChoice == _LocationChoice.skip) ...[
          const SizedBox(height: 16),
          Text(
            l10n.pointCountLocationSkipHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: 16),
        WeatherSetupCard(
          latitude: locationChoice == _LocationChoice.skip ? null : latitude,
          longitude: locationChoice == _LocationChoice.skip ? null : longitude,
          locationUnavailableLabel: l10n.pointCountLocationUnavailable,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Inference Parameters
// ─────────────────────────────────────────────────────────────────────────────

class _ParametersStep extends StatelessWidget {
  const _ParametersStep({
    super.key,
    required this.inferenceRate,
    required this.confidenceThreshold,
    required this.sensitivity,
    required this.speciesFilterMode,
    required this.onInferenceRateChanged,
    required this.onConfidenceChanged,
    required this.onSensitivityChanged,
    required this.onFilterModeChanged,
  });

  final double inferenceRate;
  final int confidenceThreshold;
  final double sensitivity;
  final String speciesFilterMode;
  final ValueChanged<double> onInferenceRateChanged;
  final ValueChanged<int> onConfidenceChanged;
  final ValueChanged<double> onSensitivityChanged;
  final ValueChanged<String> onFilterModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fileAnalysisParamsTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.fileAnalysisParamsSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // ── Inference rate ───────────────────────────────────
          _ParamTile(
            title: l10n.settingsInferenceRate,
            value: '${inferenceRate.toStringAsFixed(2)} Hz',
            child: Slider(
              value: inferenceRate,
              min: 0.25,
              max: 4.0,
              divisions: 15,
              onChanged: onInferenceRateChanged,
            ),
          ),

          // ── Confidence threshold ─────────────────────────────
          _ParamTile(
            title: l10n.settingsConfidenceThreshold,
            value: '$confidenceThreshold%',
            child: Slider(
              value: confidenceThreshold.toDouble(),
              min: 1,
              max: 99,
              divisions: 98,
              onChanged: (v) => onConfidenceChanged(v.round()),
            ),
          ),

          // ── Sensitivity ──────────────────────────────────────
          _ParamTile(
            title: l10n.settingsSensitivity,
            value: sensitivity.toStringAsFixed(1),
            child: Slider(
              value: sensitivity,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              onChanged: onSensitivityChanged,
            ),
          ),

          // ── Species filter mode ──────────────────────────────
          _ParamTile(
            title: l10n.settingsSpeciesFilter,
            value: '',
            child: DropdownButton<String>(
              value: speciesFilterMode,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'off',
                  child: Text(l10n.settingsFilterOff),
                ),
                DropdownMenuItem(
                  value: 'geoExclude',
                  child: Text(l10n.settingsFilterGeoExclude),
                ),
                DropdownMenuItem(
                  value: 'geoMerge',
                  child: Text(l10n.settingsFilterGeoMerge),
                ),
              ],
              onChanged: (v) {
                if (v != null) onFilterModeChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamTile extends StatelessWidget {
  const _ParamTile({
    required this.title,
    required this.value,
    required this.child,
  });

  final String title;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (value.isNotEmpty) ...[
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Field Tips
// ─────────────────────────────────────────────────────────────────────────────

class _TipsStep extends StatelessWidget {
  const _TipsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final tips = [
      (AppIcons.landscapeRounded, l10n.pointCountTipStableSurface),
      (AppIcons.airRounded, l10n.pointCountTipWind),
      (AppIcons.volumeOffRounded, l10n.pointCountTipQuiet),
      (AppIcons.micExternalOnRounded, l10n.pointCountTipMicrophone),
      (AppIcons.volumeMuteRounded, l10n.pointCountTipDisturbance),
      (AppIcons.scienceRounded, l10n.pointCountTipConsistency),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.pointCountFieldTips,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...tips.map((tip) {
          final (icon, text) = tip;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Ready
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep({super.key, this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final durationMin = ref.watch(pointCountDurationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.timerRounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.pointCountReady,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pointCountReadyMessage(durationMin),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          // Site context: place name + current weather, fetched live so
          // the user knows what the session will record before pressing
          // Start. Hidden when no GPS coordinates are set.
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SiteContextCard(
                  latitude: latitude!,
                  longitude: longitude!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
