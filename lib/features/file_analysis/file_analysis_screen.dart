// =============================================================================
// File Analysis Screen — Wizard-style workflow for offline file analysis
// =============================================================================
//
// Guides the user through the complete file analysis process:
//
//   **Step 1 — Pick File**
//     Select a WAV or FLAC audio file from the device.  Shows file metadata
//     (name, format, duration, size) after selection.
//
//   **Step 2 — Location**
//     Choose how to geotag the recording: use current GPS, enter coordinates
//     manually, or skip.  Location enables the geo-model species filter.
//
//   **Step 3 — Analysis Parameters**
//     Configure window duration, overlap, sensitivity, confidence threshold,
//     and species filter mode.  Defaults come from the app's global settings.
//
//   **Step 4 — Analyze**
//     Shows a progress bar with window count, detections, and species found.
//     The user can cancel the analysis at any time.
//
//   **→ Session Review**
//     On completion, navigates to [SessionReviewScreen] with the results.
//
// Uses PageView for smooth horizontal transitions between steps.
// =============================================================================

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/quick_action_service.dart';
import '../../shared/services/shared_media_service.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../../shared/widgets/map_picker_screen.dart';
import '../../shared/widgets/stat_chip.dart';
import '../../shared/widgets/wizard_scaffold.dart';
import '../../shared/utils/app_icons.dart';
import '../explore/explore_providers.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../inference/species_ignore_filter.dart';
import '../live/live_providers.dart';
import '../settings/settings_screen.dart';
import 'file_analysis_controller.dart';
import 'file_analysis_providers.dart';

/// Tracks mounted File Analysis routes so a shared audio file can replace the
/// screen the user already has open instead of stacking another one on top.
abstract final class FileAnalysisScreenPresence {
  static final Set<Route<dynamic>> _routes = <Route<dynamic>>{};

  /// Prefer the visible route, then the most recently mounted route.
  static Route<dynamic>? get mountedRoute {
    for (final route in _routes.toList().reversed) {
      if (route.isCurrent) return route;
    }
    if (_routes.isEmpty) return null;
    return _routes.last;
  }

  static void register(Route<dynamic> route) => _routes.add(route);

  static void unregister(Route<dynamic> route) => _routes.remove(route);
}

/// File analysis wizard screen.
class FileAnalysisScreen extends ConsumerStatefulWidget {
  const FileAnalysisScreen({super.key, this.sharedFile});

  /// An audio file handed to the app from another app's share sheet.
  ///
  /// When set, the screen imports and inspects it on open so step 1 starts
  /// filled in, instead of waiting for the user to pick a file.
  final SharedAudioFile? sharedFile;

  @override
  ConsumerState<FileAnalysisScreen> createState() => _FileAnalysisScreenState();
}

class _FileAnalysisScreenState extends ConsumerState<FileAnalysisScreen> {
  final PageController _pageController = PageController();
  final Object _quickListenSafetyOwner = Object();
  Route<dynamic>? _presenceRoute;
  int _currentStep = 0;

  // ── Step 1: File ──────────────────────────────────────────────────────
  String? _filePath;
  AudioFileInfo? _fileInfo;
  bool _isInspecting = false;

  // ── Step 2: Location & Date ────────────────────────────────────────────
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isFetchingLocation = false;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  DateTime? _recordingDate;

  // ── Step 3: Parameters ────────────────────────────────────────────────
  late int _windowDuration;
  late double _overlap;
  late double _sensitivity;
  late int _confidenceThreshold;
  late String _speciesFilterMode;

  // ── Step 4: Analysis ──────────────────────────────────────────────────
  bool _modelLoaded = false;
  bool _analysisLaunchInProgress = false;

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AppHelpBottomSheet(
            title: l10n.fileAnalysisHelpTitle,
            sections: [
              AppHelpSection(
                icon: AppIcons.audioFileRounded,
                body: l10n.fileAnalysisHelpSteps,
              ),
              AppHelpSection(
                icon: AppIcons.locationOnRounded,
                body: l10n.fileAnalysisHelpLocation,
              ),
              AppHelpSection(
                icon: AppIcons.playArrowRounded,
                body: l10n.fileAnalysisHelpAnalyze,
              ),
            ],
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize parameters from global settings.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _windowDuration = ref.read(windowDurationProvider);
      _sensitivity = ref.read(sensitivityProvider);
      _confidenceThreshold = ref.read(confidenceThresholdProvider);
      _speciesFilterMode = ref.read(speciesFilterModeProvider);
      _overlap = 0.0;
      setState(() {});
    });

    // Default values before settings are read.
    _windowDuration = 3;
    _overlap = 0.0;
    _sensitivity = 1.0;
    _confidenceThreshold = 35;
    _speciesFilterMode = 'off';

    final sharedFile = widget.sharedFile;
    if (sharedFile != null) {
      _isInspecting = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadSharedFile(sharedFile));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _presenceRoute)) return;
    final previousRoute = _presenceRoute;
    if (previousRoute != null) {
      FileAnalysisScreenPresence.unregister(previousRoute);
    }
    _presenceRoute = route;
    FileAnalysisScreenPresence.register(route);
  }

  @override
  void dispose() {
    final presenceRoute = _presenceRoute;
    if (presenceRoute != null) {
      FileAnalysisScreenPresence.unregister(presenceRoute);
    }
    QuickListenSafety.unregisterIncompatibleSessionOwner(
      _quickListenSafetyOwner,
    );
    _pageController.dispose();
    _latController.dispose();
    _lonController.dispose();

    // Clear state listener on the long-lived controller.
    ref.read(fileAnalysisControllerProvider).onStateChanged = null;

    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // Auto-fetch GPS when entering the location step with GPS selected.
    if (step == 1 &&
        _locationChoice == _LocationChoice.gps &&
        _latitude == null) {
      _fetchGpsLocation();
    }
  }

  bool get _canProceed {
    return switch (_currentStep) {
      0 => _fileInfo != null,
      1 => true,
      2 => true,
      _ => false,
    };
  }

  // ── File Picking ──────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _filePath = null;
      _fileInfo = null;
      _isInspecting = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'wav', 'wave', 'flac', // Lossless (pure-Dart decoder)
          'mp3', 'ogg', 'oga', 'opus', // Compressed (native decoder)
          'm4a', 'aac', 'mp4', // AAC containers
          'wma', 'amr', // Other
        ],
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isInspecting = false);
        return;
      }
      final path = result.files.first.path;
      if (path == null) {
        if (mounted) setState(() => _isInspecting = false);
        return;
      }
      if (!mounted) return;

      setState(() {
        _filePath = path;
        _fileInfo = null;
      });

      await _inspect(path);
    } catch (e) {
      debugPrint('[FileAnalysis] file inspection failed: $e');
      if (mounted) {
        setState(() => _isInspecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fileAnalysisCouldNotProcessFile)),
        );
      }
    }
  }

  /// Imports a file another app shared with us, then inspects it like a
  /// picked one. The copy runs here rather than during the hand-off so the
  /// step-1 spinner covers it — a long recording takes seconds to import.
  Future<void> _loadSharedFile(SharedAudioFile sharedFile) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await SharedMediaService.importSharedFile(sharedFile);
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _fileInfo = null;
      });
      await _inspect(path);
    } catch (e) {
      debugPrint('[FileAnalysis] shared file import failed: $e');
      // A successful import releases the staging copy itself; a failed one has
      // to, or the abandoned hand-off stays on disk with no way back to it.
      unawaited(SharedMediaService.discardSharedFile(sharedFile));
      if (mounted) {
        setState(() => _isInspecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fileAnalysisCouldNotProcessFile)),
        );
      }
    }
  }

  /// Reads metadata for [path] and finishes the step-1 loading state.
  Future<void> _inspect(String path) async {
    final controller = ref.read(fileAnalysisControllerProvider);
    final info = await controller.inspectFile(path);
    if (!mounted) return;
    setState(() {
      _fileInfo = info;
      _isInspecting = false;
    });
  }

  // ── Location ──────────────────────────────────────────────────────────

  Future<void> _fetchGpsLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await ref.read(currentLocationProvider.future);
      if (location != null && mounted) {
        _latitude = location.latitude;
        _longitude = location.longitude;
        // Reverse geocode for display name.
        _locationName = await reverseGeocode(
          latitude: location.latitude,
          longitude: location.longitude,
          localeName: ref.read(effectiveAppLocaleProvider),
        );
      }
    } catch (_) {
      // Location unavailable.
    }
    if (mounted) setState(() => _isFetchingLocation = false);
  }

  void _parseManualLocation() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat != null && lon != null) {
      _latitude = lat.clamp(-90.0, 90.0);
      _longitude = lon.clamp(-180.0, 180.0);
      _locationName = null;
    }
  }

  // ── Analysis ──────────────────────────────────────────────────────────

  Future<void> _startAnalysis() async {
    if (_analysisLaunchInProgress) return;
    _analysisLaunchInProgress = true;
    QuickListenSafety.registerIncompatibleSessionOwner(
      _quickListenSafetyOwner,
      QuickListenSessionOwner.fileAnalysis,
    );
    try {
      await _runAnalysis();
    } finally {
      QuickListenSafety.unregisterIncompatibleSessionOwner(
        _quickListenSafetyOwner,
      );
      _analysisLaunchInProgress = false;
    }
  }

  Future<void> _runAnalysis() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(fileAnalysisControllerProvider);

    // Load model if needed.
    if (!_modelLoaded) {
      await controller.loadModel();
      if (controller.state == FileAnalysisState.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                controller.errorMessage ?? l10n.fileAnalysisModelError,
              ),
            ),
          );
        }
        return;
      }
      _modelLoaded = true;
    }

    // Set up state change listener for progress updates.
    controller.onStateChanged = () {
      if (!mounted) return;
      ref.read(fileAnalysisStateProvider.notifier).state = controller.state;
      ref.read(fileAnalysisProgressProvider.notifier).state =
          controller.progress;
      setState(() {});
    };

    // Resolve location-dependent data.
    if (_locationChoice == _LocationChoice.manual) {
      _parseManualLocation();
    }

    // Fetch geo-model scores if location is available and filter is active.
    Map<String, double>? geoScores;
    Set<String>? geoSpeciesNames;
    var ignoredSpeciesNames = <String>{};
    final ignoreSettings = ref.read(speciesIgnoreSettingsProvider);
    if (_latitude != null && _longitude != null) {
      try {
        final geoModel = await ref.read(geoModelProvider.future);
        geoSpeciesNames = (await ref.read(geoModelSpeciesNamesProvider.future));
        final refDate = _recordingDate ?? DateTime.now();
        final week = _weekNumber(refDate);
        final rawGeoScores = await geoModel.predict(
          latitude: _latitude!,
          longitude: _longitude!,
          week: week,
        );
        final classes = await ref.read(audioLabelClassesProvider.future);
        ignoredSpeciesNames = SpeciesIgnoreFilter.ignoredScientificNames(
          classByScientificName: classes,
          settings: ignoreSettings,
          geoScores: rawGeoScores,
        );
        geoScores = SpeciesIgnoreFilter.applyToGeoScores(
          rawGeoScores,
          ignoredSpeciesNames,
        );
      } catch (_) {
        // Geo-model unavailable — proceed without.
      }
    }

    if (ignoredSpeciesNames.isEmpty) {
      final classes = await ref.read(audioLabelClassesProvider.future);
      ignoredSpeciesNames = SpeciesIgnoreFilter.ignoredScientificNames(
        classByScientificName: classes,
        settings: ignoreSettings,
        geoScores: geoScores,
      );
      if (geoScores != null) {
        geoScores = SpeciesIgnoreFilter.applyToGeoScores(
          geoScores,
          ignoredSpeciesNames,
        );
      }
    }

    final poolingMode = ref.read(scorePoolingProvider);
    final maxPoolWindows = ref.read(scorePoolingWindowsProvider);
    final poolingMaxAgeSeconds = ref.read(scorePoolingMaxAgeSecondsProvider);

    final session = await controller.analyze(
      filePath: _filePath!,
      windowDuration: _windowDuration,
      overlap: _overlap,
      sensitivity: _sensitivity,
      confidenceThreshold: _confidenceThreshold,
      speciesFilterMode: _speciesFilterMode,
      poolingMode: poolingMode,
      maxPoolWindows: maxPoolWindows,
      poolingMaxAgeSeconds: poolingMaxAgeSeconds,
      advancedPooling: ref.read(advancedPoolingParamsProvider),
      ignoreSettings: ignoreSettings,
      ignoredSpeciesNames: ignoredSpeciesNames,
      geoScores: geoScores,
      geoThreshold: ref.read(geoThresholdProvider),
      geoModelSpeciesNames: geoSpeciesNames,
      latitude: _latitude,
      longitude: _longitude,
      locationName: _locationName,
      recordingDate: _recordingDate,
    );

    if (session != null && mounted) {
      // Save session and navigate to review.
      final repo = ref.read(sessionRepositoryProvider);
      session.sessionNumber = await repo.nextSessionNumber(session.type);
      await repo.save(session);
      ref.invalidate(sessionListProvider);

      controller.reset();

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (a, b, c) => const SessionLibraryScreen(),
          ),
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SessionReviewScreen(session: session),
          ),
        );
      }
    } else {
      if (mounted && controller.state == FileAnalysisState.ready) {
        // Canceled! Go back to Step 3 (Parameters).
        _goToStep(2);
      }
    }
  }

  int _weekNumber(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(jan1).inDays + 1;
    return ((dayOfYear / 7.0).ceil()).clamp(1, 48);
  }

  /// Confirms with the user, then cancels the running analysis.
  ///
  /// Returns `true` if the analysis was canceled, `false` otherwise.
  Future<bool> _confirmCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.fileAnalysisCancelTitle,
      body: l10n.fileAnalysisCancelMessage,
      confirmLabel: l10n.fileAnalysisCancelConfirm,
      cancelLabel: l10n.fileAnalysisCancelKeep,
    );
    if (!confirmed || !mounted) return false;
    ref.read(fileAnalysisControllerProvider).cancel();
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final analysisState = ref.watch(fileAnalysisStateProvider);
    final isAnalyzing = analysisState == FileAnalysisState.analyzing;

    return PopScope(
      canPop: !isAnalyzing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isAnalyzing) {
          ref.read(fileAnalysisControllerProvider).cancel();
        }
      },
      child: WizardScaffold(
        title: l10n.fileAnalysisMode,
        step: _currentStep,
        totalSteps: 4,
        leading:
            isAnalyzing
                ? IconButton(
                  icon: const Icon(AppIcons.close),
                  tooltip: l10n.tooltipCancelAnalysis,
                  onPressed: _confirmCancel,
                )
                : null,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.helpOutlineRounded, size: 20),
            onPressed: _showHelp,
            tooltip: l10n.fileAnalysisHelpTitle,
          ),
          IconButton(
            icon: const Icon(AppIcons.tuneRounded, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => const SettingsScreen(
                        settingsContext: SettingsContext.fileAnalysis,
                      ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
        showFooter: !isAnalyzing && analysisState != FileAnalysisState.complete,
        onBack: _currentStep > 0 ? () => _goToStep(_currentStep - 1) : null,
        onNext:
            _currentStep == 3
                ? _startAnalysis
                : (_canProceed ? () => _goToStep(_currentStep + 1) : null),
        backLabel: l10n.fileAnalysisBack,
        nextLabel:
            _currentStep == 3 ? l10n.fileAnalysisStart : l10n.fileAnalysisNext,
        nextIcon: _currentStep == 3 ? AppIcons.playArrow : null,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentStep = i),
          children: [
            _FileStep(
              fileInfo: _fileInfo,
              isInspecting: _isInspecting,
              onPickFile: _pickFile,
            ),
            _LocationStep(
              choice: _locationChoice,
              latitude: _latitude,
              longitude: _longitude,
              locationName: _locationName,
              isFetching: _isFetchingLocation,
              latController: _latController,
              lonController: _lonController,
              recordingDate: _recordingDate,
              onChoiceChanged: (c) {
                setState(() => _locationChoice = c);
                if (c == _LocationChoice.gps) _fetchGpsLocation();
              },
              onFetchGps: _fetchGpsLocation,
              onDateChanged: (d) => setState(() => _recordingDate = d),
              onMapPick: (lat, lon) {
                setState(() {
                  _latitude = lat;
                  _longitude = lon;
                  _locationName = null;
                });
              },
            ),
            _ParametersStep(
              windowDuration: _windowDuration,
              overlap: _overlap,
              sensitivity: _sensitivity,
              confidenceThreshold: _confidenceThreshold,
              speciesFilterMode: _speciesFilterMode,
              onWindowDurationChanged:
                  (v) => setState(() => _windowDuration = v),
              onOverlapChanged: (v) => setState(() => _overlap = v),
              onSensitivityChanged: (v) => setState(() => _sensitivity = v),
              onConfidenceChanged:
                  (v) => setState(() => _confidenceThreshold = v),
              onFilterModeChanged:
                  (v) => setState(() => _speciesFilterMode = v),
            ),
            _AnalysisStep(
              state: analysisState,
              progress: ref.watch(fileAnalysisProgressProvider),
              errorMessage:
                  ref.read(fileAnalysisControllerProvider).errorMessage,
              fileInfo: _fileInfo,
              onCancel: _confirmCancel,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Location choice enum
// =============================================================================

enum _LocationChoice { gps, manual, skip }

// =============================================================================
// Step 1: File Selection
// =============================================================================

class _FileStep extends StatelessWidget {
  const _FileStep({
    required this.fileInfo,
    required this.isInspecting,
    required this.onPickFile,
  });

  final AudioFileInfo? fileInfo;
  final bool isInspecting;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fileAnalysisPickTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.fileAnalysisPickSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // ── Pick button ──────────────────────────────────────
          FilledButton.icon(
            onPressed: isInspecting ? null : onPickFile,
            icon: const Icon(AppIcons.audioFileRounded),
            label: Text(
              fileInfo == null
                  ? l10n.fileAnalysisPickButton
                  : l10n.fileAnalysisChangeFile,
            ),
          ),

          if (isInspecting) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.fileAnalysisReading,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],

          // ── File metadata card ───────────────────────────────
          if (fileInfo != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.audioFileRounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            fileInfo!.fileName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MetadataRow(
                      icon: AppIcons.straighten,
                      label: l10n.fileAnalysisFormat,
                      value: fileInfo!.format,
                    ),
                    _MetadataRow(
                      icon: AppIcons.timerOutlined,
                      label: l10n.fileAnalysisDuration,
                      value: fileInfo!.durationText,
                    ),
                    _MetadataRow(
                      icon: AppIcons.storage,
                      label: l10n.fileAnalysisSize,
                      value: fileInfo!.fileSizeText,
                    ),
                    _MetadataRow(
                      icon: AppIcons.graphicEq,
                      label: l10n.fileAnalysisSampleRate,
                      value: '${fileInfo!.sampleRate} Hz',
                    ),
                    _MetadataRow(
                      icon: AppIcons.memory,
                      label: l10n.fileAnalysisDecodedSize,
                      value: fileInfo!.decodedSizeText,
                    ),
                  ],
                ),
              ),
            ),
            if (fileInfo!.hasLargeDecodedFootprint) ...[
              const SizedBox(height: 12),
              _LargeAudioWarning(fileInfo: fileInfo!),
            ],
          ],
        ],
      ),
    );
  }
}

class _LargeAudioWarning extends StatelessWidget {
  const _LargeAudioWarning({required this.fileInfo});

  final AudioFileInfo fileInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.memory, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fileAnalysisLargeFileTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.fileAnalysisLargeFileBody(fileInfo.decodedSizeText),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
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

// =============================================================================
// Step 2: Location
// =============================================================================

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.choice,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.isFetching,
    required this.latController,
    required this.lonController,
    required this.recordingDate,
    required this.onChoiceChanged,
    required this.onFetchGps,
    required this.onDateChanged,
    required this.onMapPick,
  });

  final _LocationChoice choice;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final bool isFetching;
  final TextEditingController latController;
  final TextEditingController lonController;
  final DateTime? recordingDate;
  final void Function(_LocationChoice) onChoiceChanged;
  final VoidCallback onFetchGps;
  final ValueChanged<DateTime?> onDateChanged;
  final void Function(double lat, double lon) onMapPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fileAnalysisLocationTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.fileAnalysisLocationSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // ── Location mode selector ──────────────────────────
          SegmentedButton<_LocationChoice>(
            segments: [
              ButtonSegment(
                value: _LocationChoice.gps,
                icon: const Icon(AppIcons.myLocation, size: 18),
                label: Text(l10n.fileAnalysisLocationGps),
              ),
              ButtonSegment(
                value: _LocationChoice.manual,
                icon: const Icon(AppIcons.editLocationAlt, size: 18),
                label: Text(l10n.fileAnalysisLocationManual),
              ),
              ButtonSegment(
                value: _LocationChoice.skip,
                icon: const Icon(AppIcons.locationOff, size: 18),
                label: Text(l10n.fileAnalysisLocationSkip),
              ),
            ],
            selected: {choice},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              onChoiceChanged(s.first);
            },
            showSelectedIcon: false,
          ),

          // ── GPS result ───────────────────────────────────────
          if (choice == _LocationChoice.gps) ...[
            const SizedBox(height: 16),
            if (isFetching)
              const Center(child: CircularProgressIndicator())
            else if (latitude != null && longitude != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (locationName != null) ...[
                        Text(locationName!, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        '${latitude!.toStringAsFixed(4)}, '
                        '${longitude!.toStringAsFixed(4)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onFetchGps,
                icon: const Icon(AppIcons.refresh, size: 18),
                label: Text(l10n.fileAnalysisLocationRefresh),
              ),
            ],
          ],

          // ── Manual input ─────────────────────────────────────
          if (choice == _LocationChoice.manual) ...[
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
                      labelText: l10n.fileAnalysisLatitude,
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
                      labelText: l10n.fileAnalysisLongitude,
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
              label: Text(l10n.fileAnalysisPickOnMap),
            ),
          ],

          // ── Recording date (optional) ─────────────────────
          const SizedBox(height: 24),
          Text(
            l10n.fileAnalysisDateTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.fileAnalysisDateSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _DatePickerTile(
            selectedDate: recordingDate,
            onDateChanged: onDateChanged,
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final label =
        selectedDate != null
            ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
            : l10n.fileAnalysisDateToday;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(2000),
                lastDate: now,
              );
              if (picked != null) onDateChanged(picked);
            },
            icon: const Icon(AppIcons.calendarToday, size: 18),
            label: Text(label),
          ),
        ),
        if (selectedDate != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => onDateChanged(null),
            icon: const Icon(AppIcons.clear, size: 18),
            tooltip: l10n.fileAnalysisDateClear,
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Step 3: Analysis Parameters
// =============================================================================

class _ParametersStep extends StatelessWidget {
  const _ParametersStep({
    required this.windowDuration,
    required this.overlap,
    required this.sensitivity,
    required this.confidenceThreshold,
    required this.speciesFilterMode,
    required this.onWindowDurationChanged,
    required this.onOverlapChanged,
    required this.onSensitivityChanged,
    required this.onConfidenceChanged,
    required this.onFilterModeChanged,
  });

  final int windowDuration;
  final double overlap;
  final double sensitivity;
  final int confidenceThreshold;
  final String speciesFilterMode;
  final ValueChanged<int> onWindowDurationChanged;
  final ValueChanged<double> onOverlapChanged;
  final ValueChanged<double> onSensitivityChanged;
  final ValueChanged<int> onConfidenceChanged;
  final ValueChanged<String> onFilterModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const windowDurationValues = [1, 3, 5, 7, 10, 15];
    final windowDurationIndex = windowDurationValues.indexOf(windowDuration);
    final effectiveWindowDurationIndex =
        windowDurationIndex >= 0 ? windowDurationIndex : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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

          // ── Window duration ──────────────────────────────────
          _ParamTile(
            title: l10n.settingsWindowDuration,
            value: '${windowDuration}s',
            child: Slider(
              value: effectiveWindowDurationIndex.toDouble(),
              min: 0,
              max: (windowDurationValues.length - 1).toDouble(),
              divisions: windowDurationValues.length - 1,
              label: '${windowDurationValues[effectiveWindowDurationIndex]}s',
              onChanged:
                  (v) =>
                      onWindowDurationChanged(windowDurationValues[v.round()]),
            ),
          ),

          // ── Overlap ──────────────────────────────────────────
          _ParamTile(
            title: l10n.fileAnalysisOverlap,
            value: '${(overlap * 100).round()}%',
            child: Slider(
              value: overlap,
              min: 0.0,
              max: 0.75,
              divisions: 3,
              onChanged: onOverlapChanged,
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
                  value: 'geoAdaptive',
                  child: Text(l10n.settingsFilterGeoAdaptive),
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
          value.isEmpty
              ? child
              : Semantics(label: title, value: value, child: child),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 4: Analysis Progress
// =============================================================================

class _AnalysisStep extends StatefulWidget {
  const _AnalysisStep({
    required this.state,
    required this.progress,
    required this.errorMessage,
    required this.fileInfo,
    required this.onCancel,
  });

  final FileAnalysisState state;
  final AnalysisProgress progress;
  final String? errorMessage;
  final AudioFileInfo? fileInfo;
  final VoidCallback onCancel;

  @override
  State<_AnalysisStep> createState() => _AnalysisStepState();
}

class _AnalysisStepState extends State<_AnalysisStep> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncStopwatch();
  }

  @override
  void didUpdateWidget(covariant _AnalysisStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncStopwatch();
    }
  }

  void _syncStopwatch() {
    if (widget.state == FileAnalysisState.analyzing) {
      if (!_stopwatch.isRunning) {
        _stopwatch.start();
      }
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
      _stopwatch.stop();
      if (widget.state != FileAnalysisState.analyzing &&
          widget.state != FileAnalysisState.complete) {
        _stopwatch.reset();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  /// Format an estimated remaining duration as e.g. "45s", "1m 23s", "1h 5m".
  String _formatRemaining(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = totalSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }

  /// Compute ETA label, or null while still warming up (< ~2 seconds or < 2% done).
  String? _etaLabel(AppLocalizations l10n) {
    final fraction = widget.progress.fraction;
    final elapsed = _stopwatch.elapsed;
    if (elapsed.inMilliseconds < 2000 || fraction < 0.02) {
      return l10n.fileAnalysisEtaCalculating;
    }
    final estimatedTotalMs = elapsed.inMilliseconds / fraction;
    final remainingMs = (estimatedTotalMs - elapsed.inMilliseconds).round();
    if (remainingMs <= 0) return null;
    return l10n.fileAnalysisEtaRemaining(
      _formatRemaining(Duration(milliseconds: remainingMs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    final progress = widget.progress;
    final fileInfo = widget.fileInfo;
    final errorMessage = widget.errorMessage;
    final onCancel = widget.onCancel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fileAnalysisAnalyzeTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (state == FileAnalysisState.ready ||
              state == FileAnalysisState.idle ||
              state == FileAnalysisState.loading) ...[
            Text(
              l10n.fileAnalysisReadyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (fileInfo != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileInfo.fileName,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fileInfo.durationText} · ${fileInfo.format} · ${fileInfo.fileSizeText}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (fileInfo.hasLargeDecodedFootprint) ...[
                const SizedBox(height: 12),
                _LargeAudioWarning(fileInfo: fileInfo),
              ],
            ],
          ],
          if (state == FileAnalysisState.analyzing) ...[
            const SizedBox(height: 32),

            // ── Progress bar ──────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.totalWindows > 0 ? progress.fraction : null,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 12),

            // ── Progress text ─────────────────────────────────
            Center(
              child: Text(
                progress.totalWindows > 0
                    ? l10n.fileAnalysisProgressWindows(
                      progress.currentWindow,
                      progress.totalWindows,
                    )
                    : l10n.fileAnalysisReading,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── ETA ───────────────────────────────────────────
            Builder(
              builder: (_) {
                final eta = _etaLabel(l10n);
                if (eta == null) return const SizedBox(height: 24);
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  child: Center(
                    child: Text(
                      eta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Stats cards ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: StatChip(
                    icon: AppIcons.detections,
                    label: l10n.fileAnalysisDetections,
                    value: '${progress.detectionsFound}',
                    variant: StatChipVariant.card,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatChip(
                    icon: AppIcons.species,
                    label: l10n.fileAnalysisSpecies,
                    value: '${progress.speciesFound}',
                    variant: StatChipVariant.card,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Cancel button ─────────────────────────────────
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(AppIcons.stop),
              label: Text(l10n.cancel),
            ),
          ],
          if (state == FileAnalysisState.error) ...[
            const SizedBox(height: 24),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.errorOutline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.fileAnalysisError,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage ?? l10n.fileAnalysisCouldNotProcessFile,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
