// =============================================================================
// Point Count Setup Screen — Wizard for configuring a timed point-count survey
// =============================================================================
//
// A three-step setup wizard following standard point-count protocol:
//
//   1. **Duration & Context** — Select count duration (3–20 min), choose
//      location (GPS / Manual with map picker / Skip), and display date.
//   2. **Field Tips** — Best-practice reminders (stable surface, avoid wind,
//      stay quiet, microphone placement, etc.).
//   3. **Ready** — Summary and explicit "Start Count" button.
//
// After the user presses Start, navigates to [PointCountLiveScreen] which
// runs the timed session with a countdown timer.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/map_picker_screen.dart';
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

class _PointCountSetupScreenState extends ConsumerState<PointCountSetupScreen> {
  int _step = 0;
  static const _totalSteps = 3;

  /// Available durations in minutes.
  static const _durations = [3, 5, 10, 15, 20];

  // ── Location state ──────────────────────────────────────────────────────
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  bool _gpsFetching = false;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start fetching GPS location immediately.
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _gpsFetching = true);
    try {
      final location = await ref.read(currentLocationProvider.future);
      if (location != null && mounted) {
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _gpsFetching = false;
        });
      } else {
        if (mounted) setState(() => _gpsFetching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _gpsFetching = false);
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PointCountLiveScreen(
          durationMinutes: durationMin,
          latitude: lat,
          longitude: lon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pointCountSetupTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(
                    settingsContext: SettingsContext.pointCount,
                  ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            _StepIndicator(currentStep: _step, totalSteps: _totalSteps),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (_step) {
                  0 => _DurationStep(
                      key: const ValueKey(0),
                      durations: _durations,
                      locationChoice: _locationChoice,
                      latitude: _latitude,
                      longitude: _longitude,
                      gpsFetching: _gpsFetching,
                      latController: _latController,
                      lonController: _lonController,
                      onLocationChoiceChanged: (c) {
                        setState(() => _locationChoice = c);
                        if (c == _LocationChoice.gps) _fetchGpsLocation();
                      },
                      onFetchGps: _fetchGpsLocation,
                      onMapPick: (lat, lon) {
                        setState(() {
                          _latitude = lat;
                          _longitude = lon;
                        });
                      },
                    ),
                  1 => _TipsStep(key: const ValueKey(1)),
                  _ => _ReadyStep(key: const ValueKey(2)),
                },
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _back,
                    child: Text(_step == 0 ? l10n.cancel : l10n.pointCountBack),
                  ),
                  const Spacer(),
                  if (_step < _totalSteps - 1)
                    FilledButton(
                      onPressed: _next,
                      child: Text(l10n.pointCountNext),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l10n.pointCountStart),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isActive = i <= currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
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
          children: durations.map((min) {
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
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: theme.colorScheme.primary),
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
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(l10n.pointCountLocationGps),
            ),
            ButtonSegment(
              value: _LocationChoice.manual,
              icon: const Icon(Icons.edit_location_alt, size: 18),
              label: Text(l10n.pointCountLocationManual),
            ),
            ButtonSegment(
              value: _LocationChoice.skip,
              icon: const Icon(Icons.location_off, size: 18),
              label: Text(l10n.pointCountLocationSkip),
            ),
          ],
          selected: {locationChoice},
          onSelectionChanged: (s) => onLocationChoiceChanged(s.first),
          showSelectedIcon: false,
        ),

        // ── GPS result ───────────────────────────────────────
        if (locationChoice == _LocationChoice.gps) ...[
          const SizedBox(height: 16),
          if (gpsFetching)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else if (latitude != null && longitude != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 18, color: theme.colorScheme.primary),
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
                      icon: const Icon(Icons.refresh, size: 18),
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
                    Icon(Icons.location_off_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withAlpha(153)),
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
                      icon: const Icon(Icons.refresh, size: 18),
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
                      decimal: true, signed: true),
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
                      decimal: true, signed: true),
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
                  builder: (_) => MapPickerScreen(
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
            icon: const Icon(Icons.map, size: 18),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Field Tips
// ─────────────────────────────────────────────────────────────────────────────

class _TipsStep extends StatelessWidget {
  const _TipsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final tips = [
      (Icons.landscape_rounded, l10n.pointCountTipStableSurface),
      (Icons.air_rounded, l10n.pointCountTipWind),
      (Icons.volume_off_rounded, l10n.pointCountTipQuiet),
      (Icons.mic_external_on_rounded, l10n.pointCountTipMicrophone),
      (Icons.volume_mute_rounded, l10n.pointCountTipDisturbance),
      (Icons.science_rounded, l10n.pointCountTipConsistency),
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
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
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
  const _ReadyStep({super.key});

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
            Icons.timer_rounded,
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
        ],
      ),
    );
  }
}
