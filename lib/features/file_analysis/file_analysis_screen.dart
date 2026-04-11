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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/map_picker_screen.dart';
import '../explore/explore_providers.dart';
import '../history/session_review_screen.dart';
import '../live/live_providers.dart';
import 'file_analysis_controller.dart';
import 'file_analysis_providers.dart';

/// File analysis wizard screen.
class FileAnalysisScreen extends ConsumerStatefulWidget {
  const FileAnalysisScreen({super.key});

  @override
  ConsumerState<FileAnalysisScreen> createState() => _FileAnalysisScreenState();
}

class _FileAnalysisScreenState extends ConsumerState<FileAnalysisScreen> {
  final PageController _pageController = PageController();
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
    _confidenceThreshold = 25;
    _speciesFilterMode = 'off';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _latController.dispose();
    _lonController.dispose();
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'wav', 'wave', 'flac', // Lossless (pure-Dart decoder)
        'mp3', 'ogg', 'oga', 'opus', // Compressed (native decoder)
        'm4a', 'aac', 'mp4', // AAC containers
        'wma', 'amr', // Other
      ],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    setState(() {
      _filePath = path;
      _fileInfo = null;
      _isInspecting = true;
    });

    try {
      final controller = ref.read(fileAnalysisControllerProvider);
      final info = await controller.inspectFile(path);
      if (mounted) {
        setState(() {
          _fileInfo = info;
          _isInspecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInspecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read file: $e')),
        );
      }
    }
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
    final controller = ref.read(fileAnalysisControllerProvider);

    // Load model if needed.
    if (!_modelLoaded) {
      await controller.loadModel();
      if (controller.state == FileAnalysisState.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(controller.errorMessage ?? 'Model error')),
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
    if (_latitude != null && _longitude != null) {
      try {
        final geoModel = await ref.read(geoModelProvider.future);
        geoSpeciesNames = (await ref.read(geoModelSpeciesNamesProvider.future));
        final refDate = _recordingDate ?? DateTime.now();
        final week = _weekNumber(refDate);
        geoScores = geoModel.predict(
          latitude: _latitude!,
          longitude: _longitude!,
          week: week,
        );
      } catch (_) {
        // Geo-model unavailable — proceed without.
      }
    }

    final session = await controller.analyze(
      filePath: _filePath!,
      windowDuration: _windowDuration,
      overlap: _overlap,
      sensitivity: _sensitivity,
      confidenceThreshold: _confidenceThreshold,
      speciesFilterMode: _speciesFilterMode,
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SessionReviewScreen(session: session),
          ),
        );
      }
    }
  }

  int _weekNumber(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(jan1).inDays + 1;
    return ((dayOfYear / 7.0).ceil()).clamp(1, 48);
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.fileAnalysisMode),
          leading: isAnalyzing
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref.read(fileAnalysisControllerProvider).cancel();
                  },
                )
              : null,
        ),
        body: Column(
          children: [
            // ── Step indicator ─────────────────────────────────────
            _StepIndicator(
              currentStep: _currentStep,
              isAnalyzing: isAnalyzing,
            ),

            // ── Page content ──────────────────────────────────────
            Expanded(
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
                    onWindowDurationChanged: (v) =>
                        setState(() => _windowDuration = v),
                    onOverlapChanged: (v) => setState(() => _overlap = v),
                    onSensitivityChanged: (v) =>
                        setState(() => _sensitivity = v),
                    onConfidenceChanged: (v) =>
                        setState(() => _confidenceThreshold = v),
                    onFilterModeChanged: (v) =>
                        setState(() => _speciesFilterMode = v),
                  ),
                  _AnalysisStep(
                    state: analysisState,
                    progress: ref.watch(fileAnalysisProgressProvider),
                    errorMessage:
                        ref.read(fileAnalysisControllerProvider).errorMessage,
                    fileInfo: _fileInfo,
                    onCancel: () {
                      ref.read(fileAnalysisControllerProvider).cancel();
                    },
                  ),
                ],
              ),
            ),

            // ── Navigation buttons ────────────────────────────────
            if (!isAnalyzing && analysisState != FileAnalysisState.complete)
              _NavigationBar(
                currentStep: _currentStep,
                canProceed: _canProceed,
                onBack:
                    _currentStep > 0 ? () => _goToStep(_currentStep - 1) : null,
                onNext:
                    _currentStep < 3 ? () => _goToStep(_currentStep + 1) : null,
                onAnalyze: _currentStep == 3 ? _startAnalysis : null,
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
// Step Indicator
// =============================================================================

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.isAnalyzing,
  });

  final int currentStep;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.fileAnalysisStepFile,
      l10n.fileAnalysisStepLocation,
      l10n.fileAnalysisStepParams,
      l10n.fileAnalysisStepAnalyze,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            _StepDot(
              index: i,
              label: labels[i],
              isActive: i == currentStep,
              isCompleted: i < currentStep,
              isAnalyzing: isAnalyzing && i == 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    this.isAnalyzing = false,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive || isCompleted
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? color : theme.colorScheme.surface,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check,
                    size: 16, color: theme.colorScheme.onPrimary)
                : isAnalyzing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isActive ? theme.colorScheme.onPrimary : color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

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
            icon: const Icon(Icons.audio_file_rounded),
            label: Text(fileInfo == null
                ? l10n.fileAnalysisPickButton
                : l10n.fileAnalysisChangeFile),
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
                          Icons.audio_file_rounded,
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
                      icon: Icons.straighten,
                      label: l10n.fileAnalysisFormat,
                      value: fileInfo!.format,
                    ),
                    _MetadataRow(
                      icon: Icons.timer_outlined,
                      label: l10n.fileAnalysisDuration,
                      value: fileInfo!.durationText,
                    ),
                    _MetadataRow(
                      icon: Icons.storage,
                      label: l10n.fileAnalysisSize,
                      value: fileInfo!.fileSizeText,
                    ),
                    _MetadataRow(
                      icon: Icons.graphic_eq,
                      label: l10n.fileAnalysisSampleRate,
                      value: '${fileInfo!.sampleRate} Hz',
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
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(l10n.fileAnalysisLocationGps),
              ),
              ButtonSegment(
                value: _LocationChoice.manual,
                icon: const Icon(Icons.edit_location_alt, size: 18),
                label: Text(l10n.fileAnalysisLocationManual),
              ),
              ButtonSegment(
                value: _LocationChoice.skip,
                icon: const Icon(Icons.location_off, size: 18),
                label: Text(l10n.fileAnalysisLocationSkip),
              ),
            ],
            selected: {choice},
            onSelectionChanged: (s) => onChoiceChanged(s.first),
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
                        Text(
                          locationName!,
                          style: theme.textTheme.titleMedium,
                        ),
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
                icon: const Icon(Icons.refresh, size: 18),
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
                        decimal: true, signed: true),
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
                        decimal: true, signed: true),
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
    final label = selectedDate != null
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
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(label),
          ),
        ),
        if (selectedDate != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => onDateChanged(null),
            icon: const Icon(Icons.clear, size: 18),
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
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3s')),
                ButtonSegment(value: 5, label: Text('5s')),
                ButtonSegment(value: 10, label: Text('10s')),
              ],
              selected: {windowDuration},
              onSelectionChanged: (s) => onWindowDurationChanged(s.first),
              showSelectedIcon: false,
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

// =============================================================================
// Step 4: Analysis Progress
// =============================================================================

class _AnalysisStep extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                        fileInfo!.fileName,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fileInfo!.durationText} · ${fileInfo!.format} · ${fileInfo!.fileSizeText}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (state == FileAnalysisState.analyzing) ...[
            const SizedBox(height: 32),

            // ── Progress bar ──────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 12),

            // ── Progress text ─────────────────────────────────
            Center(
              child: Text(
                l10n.fileAnalysisProgressWindows(
                  progress.currentWindow,
                  progress.totalWindows,
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats cards ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.bar_chart,
                    label: l10n.fileAnalysisDetections,
                    value: '${progress.detectionsFound}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: MdiIcons.feather,
                    label: l10n.fileAnalysisSpecies,
                    value: '${progress.speciesFound}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Cancel button ─────────────────────────────────
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.stop),
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
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer),
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
                      errorMessage ?? '',
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

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Navigation Bar
// =============================================================================

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.currentStep,
    required this.canProceed,
    required this.onBack,
    required this.onNext,
    required this.onAnalyze,
  });

  final int currentStep;
  final bool canProceed;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: Row(
        children: [
          if (currentStep > 0)
            OutlinedButton(
              onPressed: onBack,
              child: Text(l10n.fileAnalysisBack),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          if (currentStep < 3)
            FilledButton(
              onPressed: canProceed ? onNext : null,
              child: Text(l10n.fileAnalysisNext),
            ),
          if (currentStep == 3)
            FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.fileAnalysisStart),
            ),
        ],
      ),
    );
  }
}
