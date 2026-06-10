// =============================================================================
// Survey Setup Screen — Wizard for configuring a long-running survey
// =============================================================================
//
// A three-step setup wizard:
//
//   1. **Survey Details** — Name, location (GPS/Manual/Skip), transect ID,
//      observer name.
//   2. **Parameters** — Inference rate, GPS interval, recording mode,
//      detection sampling, max duration, auto-stop battery.
//   3. **Ready** — Summary card with warnings and "Start Survey" button.
//
// After pressing Start, navigates to [SurveyLiveScreen].
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/map_picker_screen.dart';
import '../../shared/widgets/site_context_card.dart';
import '../../shared/widgets/weather_setup_card.dart';
import '../../shared/widgets/wizard_scaffold.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../inference/custom_species_list.dart';
import '../settings/settings_screen.dart';
import 'survey_alert_engine.dart';
import 'species_alert_notifier.dart';
import 'survey_providers.dart';
import 'survey_live_screen.dart';
import 'survey_notification.dart';

/// Location choice for survey setup.
enum _LocationChoice { gps, manual, skip }

/// Setup wizard for a survey transect.
class SurveySetupScreen extends ConsumerStatefulWidget {
  const SurveySetupScreen({super.key});

  @override
  ConsumerState<SurveySetupScreen> createState() => _SurveySetupScreenState();
}

class _SurveySetupScreenState extends ConsumerState<SurveySetupScreen>
    with WidgetsBindingObserver {
  int _step = 0;
  static const _totalSteps = 5;

  // Auto-retry GPS until a fix is acquired or we give up.
  static const _maxGpsAttempts = 5;
  static const _gpsRetryDelay = Duration(seconds: 5);
  // Reuse a recent fix instead of re-fetching when the wizard is reopened
  // shortly after a previous successful fix. The refresh button forces a
  // fresh read by passing `Duration.zero`.
  static const _gpsCacheMaxAge = Duration(minutes: 2);

  // ── Step 1: Survey Details ────────────────────────────────────────────
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  bool _gpsFetching = false;
  bool _hasBackgroundGps = false;
  bool _awaitingSettingsReturn = false;
  int _gpsAttempts = 0;
  int _gpsRequestSerial = 0;
  Timer? _gpsRetryTimer;
  final _nameController = TextEditingController();
  final _transectController = TextEditingController();
  final _observerController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observerController.text = ref.read(surveyLastObserverProvider);
    _transectController.text = ref.read(surveyLastTransectIdProvider);
    // Reuse a recent fix if one is still warm — closing and reopening the
    // wizard within a couple of minutes shouldn't burn another 10s on the
    // same fix.
    _fetchGpsLocation();
    _checkBackgroundPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsRetryTimer?.cancel();
    _nameController.dispose();
    _transectController.dispose();
    _observerController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_awaitingSettingsReturn) {
        _awaitingSettingsReturn = false;
        _checkBackgroundPermission();
      }
      if (_locationChoice == _LocationChoice.gps &&
          _latitude == null &&
          !_gpsFetching) {
        // Resuming with no fix yet — restart the auto-retry budget so a user
        // who came back from settings (or just stepped outdoors) gets another
        // round of attempts rather than the stale "Location unavailable" card.
        _fetchGpsLocation();
      }
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

  Future<void> _checkBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) {
      setState(() {
        _hasBackgroundGps = permission == LocationPermission.always;
      });
    }
  }

  Future<void> _requestBackgroundPermission() async {
    var permission = await Geolocator.checkPermission();

    // First ensure we have at least whileInUse.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _awaitingSettingsReturn = true;
      await Geolocator.openAppSettings();
      return;
    }

    // Android 11+ requires the user to grant "Allow all the time" in app
    // settings — requestPermission() can only escalate to whileInUse.
    if (permission != LocationPermission.always) {
      _awaitingSettingsReturn = true;
      await Geolocator.openAppSettings();
      return;
    }

    if (mounted) {
      setState(() => _hasBackgroundGps = true);
    }
  }

  void _next() {
    if (_step == 0 && _locationChoice == _LocationChoice.manual) {
      _latitude = double.tryParse(_latController.text)?.clamp(-90, 90);
      _longitude = double.tryParse(_lonController.text)?.clamp(-180, 180);
    }
    // Validate the alerts step: watchlist mode requires a non-empty list.
    if (_step == 2) {
      final mode = AlertMode.fromPrefValue(ref.read(surveyAlertModeProvider));
      if (mode == AlertMode.watchlist) {
        final selected = ref.read(surveyAlertWatchlistNameProvider);
        if (selected.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.surveyAlertWatchlistRequired,
              ),
            ),
          );
          return;
        }
      }
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

  Future<void> _start() async {
    // Request notification permission before navigating, so the OS dialog
    // doesn't interrupt the foreground-service start on the live screen.
    await SurveyNotificationService.ensurePermission();

    if (!mounted) return;

    // Persist observer and transect for next time.
    final observer = _observerController.text.trim();
    final transect = _transectController.text.trim();
    if (observer.isNotEmpty) {
      ref.read(surveyLastObserverProvider.notifier).set(observer);
    }
    if (transect.isNotEmpty) {
      ref.read(surveyLastTransectIdProvider.notifier).set(transect);
    }

    final lat = _locationChoice == _LocationChoice.skip ? null : _latitude;
    final lon = _locationChoice == _LocationChoice.skip ? null : _longitude;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => SurveyLiveScreen(
              customName:
                  _nameController.text.trim().isEmpty
                      ? null
                      : _nameController.text.trim(),
              transectId: transect.isEmpty ? null : transect,
              observerName: observer.isEmpty ? null : observer,
              startLatitude: lat,
              startLongitude: lon,
              backgroundGps: _hasBackgroundGps,
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
            title: l10n.surveySetupHelpTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.routeRounded,
                body: l10n.surveySetupHelpSteps,
              ),
              AppHelpSection(
                icon: AppIcons.locationOnRounded,
                body: l10n.surveySetupHelpLocation,
              ),
              AppHelpSection(
                icon: AppIcons.playArrowRounded,
                body: l10n.surveySetupHelpStart,
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
      title: l10n.surveySetupTitle,
      step: _step,
      totalSteps: _totalSteps,
      actions: [
        IconButton(
          icon: const Icon(AppIcons.helpOutlineRounded, size: 20),
          onPressed: _showHelp,
          tooltip: l10n.surveySetupHelpTitle,
        ),
        IconButton(
          icon: const Icon(AppIcons.tuneRounded, size: 20),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => const SettingsScreen(
                      settingsContext: SettingsContext.survey,
                    ),
              ),
            );
          },
          tooltip: l10n.settings,
        ),
      ],
      onBack: _back,
      onNext: isLastStep ? _start : _next,
      backLabel: _step == 0 ? l10n.cancel : l10n.surveyBack,
      nextLabel: isLastStep ? l10n.surveyStart : l10n.surveyNext,
      nextIcon: isLastStep ? AppIcons.playArrowRounded : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          0 => _DetailsStep(
            key: const ValueKey(0),
            nameController: _nameController,
            transectController: _transectController,
            observerController: _observerController,
            locationChoice: _locationChoice,
            latitude: _latitude,
            longitude: _longitude,
            gpsFetching: _gpsFetching,
            hasBackgroundGps: _hasBackgroundGps,
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
            onRequestBackgroundGps: _requestBackgroundPermission,
            onMapPick: (lat, lon) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
              });
            },
          ),
          1 => const _ParametersStep(key: ValueKey(1)),
          2 => const _AlertsStep(key: ValueKey(2)),
          3 => const _FieldTipsStep(key: ValueKey(3)),
          _ => _ReadyStep(
            key: const ValueKey(4),
            hasBackgroundGps: _hasBackgroundGps,
            latitude: _latitude,
            longitude: _longitude,
          ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Survey Details
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({
    super.key,
    required this.nameController,
    required this.transectController,
    required this.observerController,
    required this.locationChoice,
    required this.latitude,
    required this.longitude,
    required this.gpsFetching,
    required this.hasBackgroundGps,
    required this.latController,
    required this.lonController,
    required this.onLocationChoiceChanged,
    required this.onFetchGps,
    required this.onRequestBackgroundGps,
    required this.onMapPick,
  });

  final TextEditingController nameController;
  final TextEditingController transectController;
  final TextEditingController observerController;
  final _LocationChoice locationChoice;
  final double? latitude;
  final double? longitude;
  final bool gpsFetching;
  final bool hasBackgroundGps;
  final TextEditingController latController;
  final TextEditingController lonController;
  final ValueChanged<_LocationChoice> onLocationChoiceChanged;
  final VoidCallback onFetchGps;
  final VoidCallback onRequestBackgroundGps;
  final void Function(double lat, double lon) onMapPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Survey name
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.surveyName,
            hintText: l10n.surveyNameHint,
            prefixIcon: const Icon(AppIcons.edit),
          ),
        ),
        const SizedBox(height: 16),

        // Transect ID
        TextField(
          controller: transectController,
          decoration: InputDecoration(
            labelText: l10n.surveyTransectId,
            hintText: l10n.surveyTransectIdHint,
            prefixIcon: const Icon(AppIcons.routeRounded),
          ),
        ),
        const SizedBox(height: 16),

        // Observer name
        TextField(
          controller: observerController,
          decoration: InputDecoration(
            labelText: l10n.surveyObserverName,
            hintText: l10n.surveyObserverNameHint,
            prefixIcon: const Icon(AppIcons.personRounded),
          ),
        ),
        const SizedBox(height: 24),

        // Location section
        Text(l10n.surveyLocation, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<_LocationChoice>(
          segments: [
            ButtonSegment(
              value: _LocationChoice.gps,
              label: Text(l10n.surveyLocationGps),
            ),
            ButtonSegment(
              value: _LocationChoice.manual,
              label: Text(l10n.surveyLocationManual),
            ),
            ButtonSegment(
              value: _LocationChoice.skip,
              label: Text(l10n.surveyLocationSkip),
            ),
          ],
          selected: {locationChoice},
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            onLocationChoiceChanged(s.first);
          },
        ),
        const SizedBox(height: 12),

        // GPS result or manual input
        if (locationChoice == _LocationChoice.gps) ...[
          if (gpsFetching)
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(l10n.pointCountLocationAcquiring),
              ),
            )
          else if (latitude != null && longitude != null)
            Card(
              child: ListTile(
                leading: const Icon(AppIcons.locationOn),
                title: Text(
                  '${latitude!.toStringAsFixed(4)}, '
                  '${longitude!.toStringAsFixed(4)}',
                ),
                trailing: IconButton(
                  icon: const Icon(AppIcons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(AppIcons.locationOff),
                title: Text(l10n.surveyLocationUnavailable),
                trailing: IconButton(
                  icon: const Icon(AppIcons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            ),
          const SizedBox(height: 8),
          WeatherSetupCard(
            latitude: latitude,
            longitude: longitude,
            locationUnavailableLabel: l10n.surveyLocationUnavailable,
          ),
          if (!hasBackgroundGps) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.tertiaryContainer,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRequestBackgroundGps,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.infoOutline,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.surveyManualGpsWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        AppIcons.chevronRight,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (hasBackgroundGps) ...[
            const SizedBox(height: 8),
            // Green privacy notice — Play Store-required disclosure that
            // the app tracks GPS in the background during a survey, paired
            // with an on-device-only reassurance. Only shown in GPS mode
            // and only after the background-location permission has been
            // granted.
            Card(
              color: AppSemanticColors.of(context).successContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.lockOutline,
                      color: AppSemanticColors.of(context).onSuccessContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.surveyBackgroundGpsNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              AppSemanticColors.of(context).onSuccessContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],

        if (locationChoice == _LocationChoice.manual) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.surveyLatitude),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.surveyLongitude),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute<LatLng>(
                  builder: (_) => const MapPickerScreen(),
                ),
              );
              if (result != null) {
                onMapPick(result.latitude, result.longitude);
              }
            },
            icon: const Icon(AppIcons.map),
            label: Text(l10n.surveyPickOnMap),
          ),
        ],

        if (locationChoice == _LocationChoice.skip)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.surveyLocationSkipNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),

        if (locationChoice != _LocationChoice.gps) ...[
          const SizedBox(height: 12),
          WeatherSetupCard(
            latitude: locationChoice == _LocationChoice.skip ? null : latitude,
            longitude:
                locationChoice == _LocationChoice.skip ? null : longitude,
            locationUnavailableLabel: l10n.surveyLocationUnavailable,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Parameters
// ─────────────────────────────────────────────────────────────────────────────

class _ParametersStep extends ConsumerWidget {
  const _ParametersStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final inferenceRate = ref.watch(surveyInferenceRateProvider);
    final confidenceThreshold = ref.watch(confidenceThresholdProvider);
    final gpsInterval = ref.watch(surveyGpsIntervalProvider);
    final maxDuration = ref.watch(surveyMaxDurationProvider);
    final recordingMode = ref.watch(surveyRecordingModeProvider);
    final clipContext = ref.watch(surveyClipContextProvider);
    final sampling = ref.watch(surveyDetectionSamplingProvider);
    final topN = ref.watch(surveyTopNPerSpeciesProvider);
    final devicesAsync = ref.watch(inputDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(l10n.surveyParametersTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 16),

        // Microphone input
        devicesAsync.when(
          loading:
              () => ListTile(
                leading: const Icon(AppIcons.micRounded),
                title: Text(l10n.surveyMicrophone),
                trailing: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          error:
              (a, b) => ListTile(
                leading: const Icon(AppIcons.micRounded),
                title: Text(l10n.surveyMicrophone),
                trailing: const Text('—'),
              ),
          data: (devices) {
            final label =
                selectedDevice == null
                    ? l10n.surveyMicSystemDefault
                    : devices
                            .where((d) => d.id == selectedDevice)
                            .map((d) => d.label.isEmpty ? d.id : d.label)
                            .firstOrNull ??
                        selectedDevice;
            return ListTile(
              leading: const Icon(AppIcons.micRounded),
              title: Text(l10n.surveyMicrophone),
              trailing: Text(label, style: theme.textTheme.bodySmall),
              onTap:
                  () => _showDevicePicker(
                    context,
                    ref,
                    l10n,
                    devices,
                    selectedDevice,
                  ),
            );
          },
        ),

        const Divider(height: 32),

        // Inference rate
        ListTile(
          leading: const Icon(AppIcons.speedRounded),
          title: Text(l10n.surveyInferenceRate),
          subtitle: Text('${inferenceRate.toStringAsFixed(2)} Hz'),
        ),
        Slider(
          value: inferenceRate,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: '${inferenceRate.toStringAsFixed(2)} Hz',
          onChanged:
              (v) => ref.read(surveyInferenceRateProvider.notifier).set(v),
        ),

        // Confidence threshold
        ListTile(
          leading: const Icon(AppIcons.verifiedRounded),
          title: Text(l10n.settingsConfidenceThreshold),
          subtitle: Text('$confidenceThreshold %'),
        ),
        Slider(
          value: confidenceThreshold.toDouble(),
          min: 5,
          max: 90,
          divisions: 17,
          label: '$confidenceThreshold %',
          onChanged:
              (v) =>
                  ref.read(confidenceThresholdProvider.notifier).set(v.round()),
        ),

        // GPS interval
        ListTile(
          leading: const Icon(AppIcons.myLocation),
          title: Text(l10n.surveyGpsInterval),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5s')),
              ButtonSegment(value: 10, label: Text('10s')),
              ButtonSegment(value: 30, label: Text('30s')),
              ButtonSegment(value: 60, label: Text('60s')),
            ],
            selected: {gpsInterval},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyGpsIntervalProvider.notifier).set(s.first);
            },
          ),
        ),

        // Max duration
        ListTile(
          leading: const Icon(AppIcons.timerRounded),
          title: Text(l10n.surveyMaxDuration),
          subtitle: Text('$maxDuration ${l10n.surveyHours}'),
        ),
        Slider(
          value: maxDuration.toDouble(),
          min: 1,
          max: 24,
          divisions: 23,
          label: '$maxDuration h',
          onChanged:
              (v) =>
                  ref.read(surveyMaxDurationProvider.notifier).set(v.round()),
        ),

        const Divider(height: 32),

        // Recording mode
        ListTile(
          leading: const Icon(AppIcons.fiberManualRecordRounded),
          title: Text(l10n.surveyRecordingMode),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'full',
                label: Text(l10n.surveyRecordingFull),
              ),
              ButtonSegment(
                value: 'detections',
                label: Text(l10n.surveyRecordingDetections),
              ),
              ButtonSegment(value: 'off', label: Text(l10n.surveyRecordingOff)),
            ],
            selected: {recordingMode},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyRecordingModeProvider.notifier).set(s.first);
            },
          ),
        ),

        // Clip context (visible only when recording mode = detections)
        if (recordingMode == 'detections') ...[
          ListTile(
            leading: const Icon(AppIcons.timerOutlined),
            title: Text(l10n.surveyClipContext),
            subtitle: Text(l10n.surveyClipContextDescription),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: clipContext.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: '±${clipContext}s',
              onChanged:
                  (v) => ref
                      .read(surveyClipContextProvider.notifier)
                      .set(v.round()),
            ),
          ),
        ],

        // Detection sampling
        ListTile(
          leading: const Icon(AppIcons.filterAltRounded),
          title: Text(l10n.surveyDetectionSampling),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'all', label: Text(l10n.surveySamplingAll)),
              ButtonSegment(
                value: 'topN',
                label: Text(l10n.surveySamplingTopN),
              ),
              ButtonSegment(
                value: 'smart',
                label: Text(l10n.surveySamplingSmart),
              ),
            ],
            selected: {sampling},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyDetectionSamplingProvider.notifier).set(s.first);
            },
          ),
        ),

        // Top N (visible only when sampling = topN or smart)
        if (sampling != 'all') ...[
          ListTile(
            leading: const Icon(AppIcons.formatListNumberedRounded),
            title: Text(l10n.surveyTopNPerSpecies),
            subtitle: Text('$topN'),
          ),
          Slider(
            value: topN.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$topN',
            onChanged:
                (v) => ref
                    .read(surveyTopNPerSpeciesProvider.notifier)
                    .set(v.round()),
          ),
        ],
      ],
    );
  }

  void _showDevicePicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<InputDeviceInfo> devices,
    String? selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder:
          (ctx) => SafeArea(
            child: RadioGroup<String?>(
              groupValue: selected,
              onChanged: (v) {
                ref.read(selectedDeviceProvider.notifier).state = v;
                Navigator.of(ctx).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.surveyMicSelect,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  RadioListTile<String?>(
                    title: Text(l10n.surveyMicSystemDefault),
                    value: null,
                  ),
                  ...devices.map(
                    (d) => RadioListTile<String?>(
                      title: Text(d.label.isEmpty ? d.id : d.label),
                      value: d.id,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Field Tips
// ─────────────────────────────────────────────────────────────────────────────

class _FieldTipsStep extends StatelessWidget {
  const _FieldTipsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final tips = [
      (AppIcons.directionsWalkRounded, l10n.surveyTipWalkSteady),
      (AppIcons.airRounded, l10n.surveyTipWind),
      (AppIcons.micExternalOnRounded, l10n.surveyTipMic),
      (AppIcons.volumeOffRounded, l10n.surveyTipSilence),
      (AppIcons.wbTwilightRounded, l10n.surveyTipTime),
      (AppIcons.repeatRounded, l10n.surveyTipRepeat),
      (AppIcons.batterySaverRounded, l10n.surveyTipBattery),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.surveyFieldTips,
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
// Step 4 — Species Alerts
// ─────────────────────────────────────────────────────────────────────────────

class _AlertsStep extends ConsumerStatefulWidget {
  const _AlertsStep({super.key});

  @override
  ConsumerState<_AlertsStep> createState() => _AlertsStepState();
}

class _AlertsStepState extends ConsumerState<_AlertsStep> {
  bool _advancedExpanded = false;
  List<String>? _watchlists;
  bool _permissionRequested = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlists();
  }

  Future<void> _loadWatchlists() async {
    try {
      final names = await CustomSpeciesList.listSaved();
      if (!mounted) return;
      setState(() => _watchlists = names);
    } catch (_) {
      if (!mounted) return;
      setState(() => _watchlists = const []);
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final notifier = ref.read(speciesAlertNotifierProvider);
      final strings = SpeciesAlertStrings(
        channelName: l10n.surveyAlertChannelName,
        channelDescription: l10n.surveyAlertChannelDescription,
        firstInSessionBody: l10n.surveyAlertBodyFirstInSession,
        firstEverBody: l10n.surveyAlertBodyFirstEver,
        rareBody: l10n.surveyAlertBodyRare('{pct}'),
        watchlistBody: l10n.surveyAlertBodyWatchlist,
        summaryTitle: l10n
            .surveyAlertSummaryTitle(0)
            .replaceAll('0', '{count}'),
        summaryBody: l10n
            .surveyAlertSummaryBody(0, '__NAMES__')
            .replaceAll('0', '{count}')
            .replaceAll('__NAMES__', '{names}'),
      );
      await notifier.requestPermission(strings: strings);
    } catch (_) {
      // Non-fatal — user can still try again from system settings.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mode = AlertMode.fromPrefValue(ref.watch(surveyAlertModeProvider));
    final modes = const [
      (AlertMode.off, 'surveyAlertModeOff', 'surveyAlertModeOffDescription'),
      (
        AlertMode.firstInSession,
        'surveyAlertModeFirstInSession',
        'surveyAlertModeFirstInSessionDescription',
      ),
      (
        AlertMode.firstEver,
        'surveyAlertModeFirstEver',
        'surveyAlertModeFirstEverDescription',
      ),
      (AlertMode.rare, 'surveyAlertModeRare', 'surveyAlertModeRareDescription'),
      (
        AlertMode.watchlist,
        'surveyAlertModeWatchlist',
        'surveyAlertModeWatchlistDescription',
      ),
    ];

    final selectedWatchlist = ref.watch(surveyAlertWatchlistNameProvider);
    final watchlistInvalid =
        mode == AlertMode.watchlist && selectedWatchlist.trim().isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.surveyAlertsTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.surveyAlertsSubtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(AppIcons.helpOutlineRounded, size: 20),
              tooltip: l10n.surveyAlertHelpModesTitle,
              onPressed: () => _showAlertsHelp(context, l10n),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RadioGroup<AlertMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) {
              ref.read(surveyAlertModeProvider.notifier).set(v.prefValue);
              if (v != AlertMode.off) {
                _ensureNotificationPermission();
              }
            }
          },
          child: Column(
            children: [
              for (final entry in modes)
                RadioListTile<AlertMode>(
                  value: entry.$1,
                  title: Text(_l10nMode(l10n, entry.$2)),
                  subtitle: Text(_l10nMode(l10n, entry.$3)),
                  dense: true,
                ),
            ],
          ),
        ),
        if (mode == AlertMode.rare) ...[
          const Divider(height: 32),
          _RareThresholdControl(),
        ],
        if (mode == AlertMode.watchlist) ...[
          const Divider(height: 32),
          _WatchlistControl(
            watchlists: _watchlists,
            onChanged: _loadWatchlists,
          ),
          if (watchlistInvalid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    AppIcons.errorOutlineRounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.surveyAlertWatchlistRequired,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (mode != AlertMode.off) ...[
          const Divider(height: 32),
          _MinConfidenceControl(),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l10n.surveyAlertSoundLabel),
            secondary: const Icon(AppIcons.volumeUpRounded),
            value: ref.watch(surveyAlertSoundProvider),
            onChanged:
                (v) => ref.read(surveyAlertSoundProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: Text(l10n.surveyAlertVibrateLabel),
            secondary: const Icon(AppIcons.vibrationRounded),
            value: ref.watch(surveyAlertVibrateProvider),
            onChanged:
                (v) => ref.read(surveyAlertVibrateProvider.notifier).set(v),
          ),
          ExpansionTile(
            title: Text(l10n.surveyAlertAdvancedTitle),
            initiallyExpanded: _advancedExpanded,
            onExpansionChanged: (v) => setState(() => _advancedExpanded = v),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              _SegmentedSecondsControl(
                label: l10n.surveyAlertGraceLabel,
                helper: l10n.surveyAlertGraceHelp,
                icon: AppIcons.hourglassTopRounded,
                value: ref.watch(surveyAlertStartupGraceSecondsProvider),
                options: const [0, 30, 60, 120, 300],
                offLabel: l10n.surveyAlertModeOff,
                onChanged:
                    (v) => ref
                        .read(surveyAlertStartupGraceSecondsProvider.notifier)
                        .set(v),
              ),
              _SegmentedSecondsControl(
                label: l10n.surveyAlertMinIntervalLabel,
                helper: l10n.surveyAlertMinIntervalHelp,
                icon: AppIcons.timerOutlined,
                value: ref.watch(surveyAlertMinIntervalSecondsProvider),
                options: const [0, 5, 15, 30, 60],
                offLabel: l10n.surveyAlertModeOff,
                onChanged:
                    (v) => ref
                        .read(surveyAlertMinIntervalSecondsProvider.notifier)
                        .set(v),
              ),
              _SegmentedCountControl(
                label: l10n.surveyAlertMaxPerMinuteLabel,
                helper: l10n.surveyAlertMaxPerMinuteHelp,
                icon: AppIcons.notificationsActiveRounded,
                value: ref.watch(surveyAlertMaxPerMinuteProvider),
                options: const [1, 3, 5, 10, 0],
                unlimitedValue: 0,
                unlimitedLabel: l10n.surveyAlertUnlimited,
                onChanged:
                    (v) => ref
                        .read(surveyAlertMaxPerMinuteProvider.notifier)
                        .set(v),
              ),
              SwitchListTile(
                title: Text(l10n.surveyAlertCoalesceLabel),
                subtitle: Text(l10n.surveyAlertCoalesceHelp),
                value: ref.watch(surveyAlertCoalesceProvider),
                onChanged:
                    (v) =>
                        ref.read(surveyAlertCoalesceProvider.notifier).set(v),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showAlertsHelp(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.surveyAlertsTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.notificationsActiveRounded,
                body:
                    '${l10n.surveyAlertHelpModesTitle}\n\n${l10n.surveyAlertHelpModesBody}',
              ),
              AppHelpSection(
                icon: AppIcons.scheduleRounded,
                body:
                    '${l10n.surveyAlertHelpThrottlingTitle}\n\n${l10n.surveyAlertHelpThrottlingBody}',
              ),
            ],
          ),
    );
  }

  String _l10nMode(AppLocalizations l10n, String key) {
    switch (key) {
      case 'surveyAlertModeOff':
        return l10n.surveyAlertModeOff;
      case 'surveyAlertModeFirstInSession':
        return l10n.surveyAlertModeFirstInSession;
      case 'surveyAlertModeFirstEver':
        return l10n.surveyAlertModeFirstEver;
      case 'surveyAlertModeRare':
        return l10n.surveyAlertModeRare;
      case 'surveyAlertModeWatchlist':
        return l10n.surveyAlertModeWatchlist;
      case 'surveyAlertModeOffDescription':
        return l10n.surveyAlertModeOffDescription;
      case 'surveyAlertModeFirstInSessionDescription':
        return l10n.surveyAlertModeFirstInSessionDescription;
      case 'surveyAlertModeFirstEverDescription':
        return l10n.surveyAlertModeFirstEverDescription;
      case 'surveyAlertModeRareDescription':
        return l10n.surveyAlertModeRareDescription;
      case 'surveyAlertModeWatchlistDescription':
        return l10n.surveyAlertModeWatchlistDescription;
    }
    return key;
  }
}

class _RareThresholdControl extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final value = ref.watch(surveyAlertRareThresholdProvider);
    final pct = (value * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(AppIcons.publicOffRounded),
          title: Text(l10n.surveyAlertRareThresholdLabel),
          subtitle: Text(
            l10n.surveyAlertRareThresholdHelp,
            style: theme.textTheme.bodySmall,
          ),
          trailing: Text('$pct%'),
        ),
        Slider(
          value: value.clamp(0.0, 0.5),
          min: 0.0,
          max: 0.5,
          divisions: 50,
          label: '$pct%',
          onChanged:
              (v) => ref.read(surveyAlertRareThresholdProvider.notifier).set(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.surveyAlertRareLiveLabel(pct),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _MinConfidenceControl extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Floor: session confidence threshold (0..100 stored as int) → 0..1.
    final sessionFloor =
        ref.watch(confidenceThresholdProvider).clamp(0, 100) / 100.0;
    final raw = ref.watch(surveyAlertMinConfidenceProvider);
    final value = raw < sessionFloor ? sessionFloor : raw;
    // Lazily clamp the persisted value if it's below the floor.
    if (raw < sessionFloor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(surveyAlertMinConfidenceProvider.notifier)
            .set(sessionFloor.toDouble());
      });
    }
    final pct = (value * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(AppIcons.verifiedRounded),
          title: Text(l10n.surveyAlertMinConfidenceLabel),
          subtitle: Text(
            l10n.surveyAlertMinConfidenceHelp,
            style: theme.textTheme.bodySmall,
          ),
          trailing: Text('$pct%'),
        ),
        Slider(
          value: value.clamp(sessionFloor, 1.0).toDouble(),
          min: sessionFloor.toDouble(),
          max: 1.0,
          divisions: ((1.0 - sessionFloor) * 100).round().clamp(1, 100),
          label: '$pct%',
          onChanged:
              (v) => ref.read(surveyAlertMinConfidenceProvider.notifier).set(v),
        ),
      ],
    );
  }
}

class _WatchlistControl extends ConsumerWidget {
  const _WatchlistControl({required this.watchlists, required this.onChanged});
  final List<String>? watchlists;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = ref.watch(surveyAlertWatchlistNameProvider);
    final lists = watchlists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(AppIcons.listAltRounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.surveyAlertWatchlistLabel,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                icon: const Icon(AppIcons.addRounded, size: 18),
                label: Text(l10n.surveyAlertCreateListButton),
                onPressed: () => _createList(context, ref),
              ),
            ],
          ),
        ),
        if (lists == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.surveyAlertWatchlistEmpty,
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...lists.map(
            (name) => _WatchlistTile(
              name: name,
              selected: selected == name,
              onSelect:
                  () => ref
                      .read(surveyAlertWatchlistNameProvider.notifier)
                      .set(name),
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        content: Text(
                          l10n.surveyAlertWatchlistDeleteConfirm(name),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l10n.surveyAlertCreateListCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(l10n.sessionRemove),
                          ),
                        ],
                      ),
                );
                if (confirmed == true) {
                  await CustomSpeciesList.delete(name);
                  if (selected == name) {
                    ref.read(surveyAlertWatchlistNameProvider.notifier).set('');
                  }
                  onChanged();
                }
              },
            ),
          ),
      ],
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const _CreateWatchlistScreen(),
      ),
    );
    if (created != null && created.isNotEmpty) {
      ref.read(surveyAlertWatchlistNameProvider.notifier).set(created);
      onChanged();
    }
  }
}

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
    required this.name,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });
  final String name;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<Set<String>>(
      future: CustomSpeciesList.load(name),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return RadioGroup<bool?>(
          groupValue: selected ? true : null,
          onChanged: (_) => onSelect(),
          child: RadioListTile<bool?>(
            value: true,
            title: Text(name),
            subtitle:
                snap.connectionState == ConnectionState.done
                    ? Text(l10n.surveyAlertSpeciesCount(count))
                    : const Text('…'),
            secondary: IconButton(
              icon: const Icon(AppIcons.deleteOutlineRounded),
              onPressed: onDelete,
              tooltip: l10n.sessionRemove,
            ),
            dense: true,
          ),
        );
      },
    );
  }
}

class _CreateWatchlistScreen extends ConsumerStatefulWidget {
  const _CreateWatchlistScreen();

  @override
  ConsumerState<_CreateWatchlistScreen> createState() =>
      _CreateWatchlistScreenState();
}

class _CreateWatchlistScreenState
    extends ConsumerState<_CreateWatchlistScreen> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  // Cache common-name labels so the "selected" list keeps a friendly label
  // even after the user clears the search and the species drops out of
  // [_results].
  final Map<String, String> _labels = <String, String>{};
  List<TaxonomySpecies> _results = const [];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final svc = ref.read(taxonomyServiceProvider).value;
    if (svc == null) return;
    setState(() {
      _results = query.trim().isEmpty ? const [] : svc.search(query, limit: 60);
    });
  }

  void _toggle(TaxonomySpecies sp, String label) {
    setState(() {
      if (_selected.contains(sp.scientificName)) {
        _selected.remove(sp.scientificName);
      } else {
        _selected.add(sp.scientificName);
        _labels[sp.scientificName] = label;
      }
    });
  }

  Future<void> _importFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final names = CustomSpeciesList.parse(content);
      if (names.isEmpty) {
        setState(() => _error = l10n.surveyAlertCreateListImportError);
        return;
      }
      final svc = ref.read(taxonomyServiceProvider).value;
      final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
      setState(() {
        _selected.addAll(names);
        if (svc != null) {
          for (final n in names) {
            final sp = svc.lookup(n);
            _labels[n] = sp?.commonNameForLocale(speciesLocale) ?? n;
          }
        } else {
          for (final n in names) {
            _labels.putIfAbsent(n, () => n);
          }
        }
        _error = null;
      });
    } catch (_) {
      setState(() => _error = l10n.surveyAlertCreateListImportError);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.surveyAlertCreateListNameLabel);
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = l10n.surveyAlertCreateListEmpty);
      return;
    }
    final existing = await CustomSpeciesList.listSaved();
    if (existing.contains(name)) {
      setState(() => _error = l10n.surveyAlertCreateListNameTaken);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await CustomSpeciesList.save(name, _selected.toSet());
    if (!mounted) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final showSci = ref.watch(showSciNamesProvider);

    String labelFor(TaxonomySpecies sp) {
      if (showSci) return sp.scientificName;
      return sp.commonNameForLocale(speciesLocale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.surveyAlertCreateListTitle),
        leading: IconButton(
          icon: const Icon(AppIcons.closeRounded),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          tooltip: l10n.surveyAlertCreateListCancel,
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(AppIcons.saveRounded, size: 18),
            label: Text(l10n.surveyAlertCreateListSave),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.surveyAlertCreateListNameLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.surveyAlertCreateListSearchHint,
                      prefixIcon: const Icon(AppIcons.searchRounded),
                      suffixIcon:
                          _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                icon: const Icon(AppIcons.clearRounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(AppIcons.uploadFileRounded),
                  tooltip: l10n.surveyAlertCreateListImportFile,
                  onPressed: _importFromFile,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _results.isEmpty
                      ? _SelectedSpeciesList(
                        selected: _selected,
                        labels: _labels,
                        onRemove:
                            (sci) => setState(() {
                              _selected.remove(sci);
                            }),
                      )
                      : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final sp = _results[i];
                          final label = labelFor(sp);
                          final isSelected = _selected.contains(
                            sp.scientificName,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggle(sp, label),
                            title: Text(label),
                            subtitle:
                                showSci
                                    ? Text(
                                      sp.commonNameForLocale(speciesLocale),
                                      style: theme.textTheme.bodySmall,
                                    )
                                    : Text(
                                      sp.scientificName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.surveyAlertCreateListSelectedHeader(_selected.length),
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedSpeciesList extends StatelessWidget {
  const _SelectedSpeciesList({
    required this.selected,
    required this.labels,
    required this.onRemove,
  });
  final Set<String> selected;
  final Map<String, String> labels;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (selected.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.surveyAlertCreateListNoSelection,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = selected.toList();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final sci = list[i];
        final label = labels[sci] ?? sci;
        return ListTile(
          leading: const Icon(AppIcons.checkRounded),
          title: Text(label),
          subtitle: Text(
            sci,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(AppIcons.closeRounded),
            onPressed: () => onRemove(sci),
            tooltip: l10n.sessionRemove,
          ),
          dense: true,
        );
      },
    );
  }
}

class _SegmentedSecondsControl extends StatelessWidget {
  const _SegmentedSecondsControl({
    required this.label,
    required this.helper,
    required this.icon,
    required this.value,
    required this.options,
    required this.offLabel,
    required this.onChanged,
  });
  final String label;
  final String helper;
  final IconData icon;
  final int value;
  final List<int> options;
  final String offLabel;
  final ValueChanged<int> onChanged;

  String _format(int seconds) {
    if (seconds == 0) return offLabel;
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 4),
          Text(helper, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final opt in options)
                ChoiceChip(
                  label: Text(_format(opt)),
                  selected: value == opt,
                  onSelected: (_) => onChanged(opt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedCountControl extends StatelessWidget {
  const _SegmentedCountControl({
    required this.label,
    required this.helper,
    required this.icon,
    required this.value,
    required this.options,
    required this.unlimitedValue,
    required this.unlimitedLabel,
    required this.onChanged,
  });
  final String label;
  final String helper;
  final IconData icon;
  final int value;
  final List<int> options;
  final int unlimitedValue;
  final String unlimitedLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 4),
          Text(helper, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final opt in options)
                ChoiceChip(
                  label: Text(
                    opt == unlimitedValue ? unlimitedLabel : opt.toString(),
                  ),
                  selected: value == opt,
                  onSelected: (_) => onChanged(opt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Ready
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep({
    super.key,
    required this.hasBackgroundGps,
    this.latitude,
    this.longitude,
  });
  final bool hasBackgroundGps;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final inferenceRate = ref.watch(surveyInferenceRateProvider);
    final gpsInterval = ref.watch(surveyGpsIntervalProvider);
    final maxDuration = ref.watch(surveyMaxDurationProvider);
    final sampling = ref.watch(surveyDetectionSamplingProvider);
    final recordingMode = ref.watch(surveyRecordingModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Icon(
            AppIcons.routeRounded,
            size: 64,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 16),
          Text(l10n.surveyReadyTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    AppIcons.speedRounded,
                    l10n.surveyInferenceRate,
                    '${inferenceRate.toStringAsFixed(2)} Hz',
                  ),
                  _SummaryRow(
                    AppIcons.myLocation,
                    l10n.surveyGpsInterval,
                    '${gpsInterval}s',
                  ),
                  _SummaryRow(
                    AppIcons.timerRounded,
                    l10n.surveyMaxDuration,
                    '$maxDuration ${l10n.surveyHours}',
                  ),
                  _SummaryRow(
                    AppIcons.filterAltRounded,
                    l10n.surveyDetectionSampling,
                    sampling,
                  ),
                  _SummaryRow(
                    AppIcons.fiberManualRecordRounded,
                    l10n.surveyRecordingMode,
                    recordingMode,
                  ),
                ],
              ),
            ),
          ),

          // Site context: place name + current weather, fetched live so
          // the user knows what the session will record before pressing
          // Start. Hidden when no GPS coordinates are set.
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
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

          const SizedBox(height: 16),

          // Warnings
          if (!hasBackgroundGps)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.warningAmberRounded,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.surveyManualGpsReadyWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
