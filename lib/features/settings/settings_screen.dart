import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_data_clear_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../about/about_screen.dart';
import '../announcements/widgets/announcements_settings_section.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../spectrogram/color_maps.dart';
import 'offline_map_download_tile.dart';

bool get _showOfflineMapDownloadSetting => false;

// ---------------------------------------------------------------------------
// Settings context — determines which settings are visible
// ---------------------------------------------------------------------------

/// The screen context from which settings are opened.
///
/// Each settings section is tagged with a set of contexts it belongs to.
/// When the settings screen is opened from a specific screen, only relevant
/// sections are shown.
enum SettingsContext {
  /// Show all settings (e.g. from a global settings entry point).
  all,

  /// Live monitoring mode.
  live,

  /// Survey mode (future).
  survey,

  /// Point-count mode (future).
  pointCount,

  /// File / recording analysis mode (future).
  fileAnalysis,
}

/// Settings screen with categorized preferences.
///
/// Pass a [settingsContext] to filter sections to only those relevant for
/// the given screen.  Defaults to [SettingsContext.all] which shows
/// everything.
///
/// Categories: General, Audio, Inference, Spectrogram, Recording, Export,
/// About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.settingsContext = SettingsContext.all});

  /// Which screen opened this settings page — controls section visibility.
  final SettingsContext settingsContext;

  /// Mapping from section tag to the set of contexts it appears in.
  ///
  /// [SettingsContext.all] is implicitly included for every section —
  /// when the screen is opened with [SettingsContext.all] everything shows.
  static const Map<String, Set<SettingsContext>> _sectionContexts = {
    'general': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
      SettingsContext.fileAnalysis,
    },
    'audio': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
    },
    'inference': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
      SettingsContext.fileAnalysis,
    },
    'spectrogram': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
    },
    'recording': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
    },
    'export': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
      SettingsContext.fileAnalysis,
    },
    'location': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
    },
    'privacy': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
      SettingsContext.fileAnalysis,
    },
    'announcements': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
    },
    'about': {
      SettingsContext.live,
      SettingsContext.survey,
      SettingsContext.pointCount,
      SettingsContext.fileAnalysis,
    },
  };

  /// Returns `true` if [section] should be visible for the current context.
  bool _showSection(String section) {
    if (settingsContext == SettingsContext.all) return true;
    return _sectionContexts[section]?.contains(settingsContext) ?? true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ContentWidthConstraint(
        child: ListView(
          children: [
            // --- General ---
            if (_showSection('general')) ...[
              _SectionHeader(
                title: l10n.settingsGeneral,
                subtitle: l10n.settingsGeneralDescription,
              ),
              _ThemeTile(l10n: l10n),
              SwitchListTile(
                title: Text(l10n.settingsDynamicColor),
                subtitle: Text(l10n.settingsDynamicColorDescription),
                value: ref.watch(dynamicColorProvider),
                onChanged:
                    (v) => ref.read(dynamicColorProvider.notifier).set(v),
              ),
              _LanguageTile(l10n: l10n),
              _SpeciesLanguageTile(l10n: l10n),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsShowSciNames,
                  helpBody: l10n.settingsHelpShowSciNames,
                ),
                subtitle: Text(l10n.settingsShowSciNamesDescription),
                value: ref.watch(showSciNamesProvider),
                onChanged:
                    (v) => ref.read(showSciNamesProvider.notifier).set(v),
              ),
              ListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsTimestampDisplayMode,
                  helpBody: l10n.settingsHelpTimestampDisplayMode,
                ),
                subtitle: Text(l10n.settingsTimestampDisplayModeDescription),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'relative',
                        label: _SegmentLabel(
                          text: l10n.settingsTimestampDisplayModeRelative,
                        ),
                      ),
                      ButtonSegment(
                        value: 'absolute',
                        label: _SegmentLabel(
                          text: l10n.settingsTimestampDisplayModeAbsolute,
                        ),
                      ),
                    ],
                    selected: {ref.watch(timestampDisplayModeProvider)},
                    onSelectionChanged: (selected) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(timestampDisplayModeProvider.notifier)
                          .set(selected.first);
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
              if (ref.watch(timestampDisplayModeProvider) == 'absolute')
                SwitchListTile(
                  title: _TitleWithHelp(
                    title: l10n.settingsTimestampShowSeconds,
                    helpBody: l10n.settingsHelpTimestampShowSeconds,
                  ),
                  subtitle: Text(l10n.settingsTimestampShowSecondsDescription),
                  value: ref.watch(timestampShowSecondsProvider),
                  onChanged:
                      (v) => ref
                          .read(timestampShowSecondsProvider.notifier)
                          .set(v),
                ),
              const Divider(),
            ],

            // --- Audio ---
            if (_showSection('audio')) ...[
              _SectionHeader(
                title: l10n.settingsAudio,
                subtitle: l10n.settingsAudioDescription,
              ),
              _SliderTile(
                title: l10n.settingsGain,
                helpBody: l10n.settingsHelpGain,
                value: ref.watch(audioGainProvider),
                min: 0.0,
                max: 2.0,
                divisions: 20,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => ref.read(audioGainProvider.notifier).set(v),
              ),
              _SliderTile(
                title: l10n.settingsHighPassFilter,
                helpBody: l10n.settingsHelpHighPassFilter,
                value: ref.watch(highPassFilterProvider),
                min: 0,
                max: 1000,
                divisions: 100,
                format: (v) => '${v.toInt()} Hz',
                onChanged:
                    (v) => ref.read(highPassFilterProvider.notifier).set(v),
              ),
              _MicInputTile(),
              const Divider(),
            ],

            // --- Inference ---
            if (_showSection('inference')) ...[
              _SectionHeader(
                title: l10n.settingsInference,
                subtitle: l10n.settingsInferenceDescription,
              ),
              _ChoiceTile<int>(
                title: l10n.settingsWindowDuration,
                helpBody: l10n.settingsHelpWindowDuration,
                value: ref.watch(windowDurationProvider),
                options: const {3: '3s', 5: '5s', 10: '10s'},
                onChanged:
                    (v) => ref.read(windowDurationProvider.notifier).set(v),
              ),
              _SliderTile(
                title: l10n.settingsConfidenceThreshold,
                helpBody: l10n.settingsHelpConfidenceThreshold,
                value: ref.watch(confidenceThresholdProvider).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                format: (v) => '${v.toInt()}%',
                onChanged:
                    (v) => ref
                        .read(confidenceThresholdProvider.notifier)
                        .set(v.toInt()),
              ),
              _SliderTile(
                title: l10n.settingsSensitivity,
                helpBody: l10n.settingsHelpSensitivity,
                value: ref.watch(sensitivityProvider),
                min: 0.5,
                max: 1.5,
                divisions: 20,
                format: (v) => v.toStringAsFixed(2),
                onChanged: (v) => ref.read(sensitivityProvider.notifier).set(v),
              ),
              _ChoiceTile<double>(
                title: l10n.settingsInferenceRate,
                helpBody: l10n.settingsHelpInferenceRate,
                value: ref.watch(inferenceRateProvider),
                options: {
                  0.25: '0.25 Hz',
                  0.5: '0.5 Hz',
                  1.0: '1 Hz',
                  2.0: '2 Hz',
                },
                onChanged:
                    (v) => ref.read(inferenceRateProvider.notifier).set(v),
              ),
              _ChoiceTile<String>(
                title: l10n.settingsScorePooling,
                helpBody: l10n.settingsHelpScorePooling,
                value: ref.watch(scorePoolingProvider),
                options: {
                  'off': l10n.settingsPoolingOff,
                  'average': l10n.settingsPoolingAverage,
                  'max': l10n.settingsPoolingMax,
                  'lme': l10n.settingsPoolingLME,
                },
                onChanged:
                    (v) => ref.read(scorePoolingProvider.notifier).set(v),
              ),
              // The pooling-windows slider only matters when pooling is on. We
              // still leave it visible (greyed out at the bottom of the section
              // would be more discoverable than hiding it entirely) so users can
              // dial it in before re-enabling pooling.
              _SliderTile(
                title: l10n.settingsScorePoolingWindows,
                helpBody: l10n.settingsHelpScorePoolingWindows,
                value: ref.watch(scorePoolingWindowsProvider).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                format: (v) => v.toInt().toString(),
                onChanged:
                    (v) => ref
                        .read(scorePoolingWindowsProvider.notifier)
                        .set(v.toInt()),
              ),
              const Divider(),
            ],

            // --- Spectrogram ---
            if (_showSection('spectrogram')) ...[
              _SectionHeader(
                title: l10n.settingsSpectrogram,
                subtitle: l10n.settingsSpectrogramDescription,
              ),
              _ChoiceTile<int>(
                title: l10n.settingsFftSize,
                helpBody: l10n.settingsHelpFftSize,
                value: ref.watch(fftSizeProvider),
                options: const {
                  512: '512',
                  1024: '1024',
                  2048: '2048',
                  4096: '4096',
                },
                onChanged: (v) => ref.read(fftSizeProvider.notifier).set(v),
              ),
              _ColorMapChoiceTile(
                title: l10n.settingsColorMap,
                helpBody: l10n.settingsHelpColorMap,
                value: ref.watch(colorMapProvider),
                options: {
                  'viridis': l10n.settingsColorMapViridis,
                  'magma': l10n.settingsColorMapMagma,
                  'grayscale': l10n.settingsColorMapGrayscale,
                },
                onChanged: (v) => ref.read(colorMapProvider.notifier).set(v),
              ),
              _ChoiceTile<int>(
                title: l10n.settingsSpectrogramDuration,
                helpBody: l10n.settingsHelpSpectrogramDuration,
                value: ref.watch(spectrogramDurationProvider),
                options: const {
                  5: '5 s',
                  10: '10 s',
                  15: '15 s',
                  20: '20 s',
                  30: '30 s',
                },
                onChanged:
                    (v) =>
                        ref.read(spectrogramDurationProvider.notifier).set(v),
              ),
              _ChoiceTile<int>(
                title: l10n.settingsFrequencyRange,
                helpBody: l10n.settingsHelpFrequencyRange,
                value: ref.watch(spectrogramMaxFreqProvider),
                options: const {
                  4000: '4 kHz',
                  6000: '6 kHz',
                  8000: '8 kHz',
                  10000: '10 kHz',
                  12000: '12 kHz',
                  16000: '16 kHz',
                },
                onChanged:
                    (v) => ref.read(spectrogramMaxFreqProvider.notifier).set(v),
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsLogAmplitude,
                  helpBody: l10n.settingsHelpLogAmplitude,
                ),
                subtitle: Text(l10n.settingsLogAmplitudeDescription),
                value: ref.watch(logAmplitudeProvider),
                onChanged:
                    (v) => ref.read(logAmplitudeProvider.notifier).set(v),
              ),
              _ChoiceTile<String>(
                title: l10n.settingsSpectrogramQuality,
                helpBody: l10n.settingsHelpSpectrogramQuality,
                value: ref.watch(spectrogramQualityProvider),
                options: {
                  'low': l10n.settingsSpectrogramQualityLow,
                  'medium': l10n.settingsSpectrogramQualityMedium,
                  'high': l10n.settingsSpectrogramQualityHigh,
                },
                onChanged:
                    (v) => ref.read(spectrogramQualityProvider.notifier).set(v),
              ),
              const Divider(),
            ],

            // --- Announcements ---
            // Sits high up in the list (right after Spectrogram) because
            // it is the only setting users typically need to revisit
            // mid-session — the verbosity × frequency pickers are the
            // entire setup, so making them easy to find matters more
            // than category alphabetization.
            if (_showSection('announcements'))
              AnnouncementsSettingsSection(
                sectionHeader:
                    ({required String title, required String subtitle}) =>
                        _SectionHeader(title: title, subtitle: subtitle),
                titleWithHelp:
                    ({required String title, String? helpBody}) =>
                        _TitleWithHelp(title: title, helpBody: helpBody),
              ),

            // --- Recording ---
            if (_showSection('recording')) ...[
              _SectionHeader(
                title: l10n.settingsRecording,
                subtitle: l10n.settingsRecordingDescription,
              ),
              ListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsRecordingMode,
                  helpBody: l10n.settingsHelpRecordingMode,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'full',
                      label: _SegmentLabel(
                        text: l10n.settingsRecordingModeFull,
                      ),
                    ),
                    ButtonSegment(
                      value: 'detections',
                      label: _SegmentLabel(
                        text: l10n.settingsRecordingModeDetections,
                      ),
                    ),
                    ButtonSegment(
                      value: 'off',
                      label: _SegmentLabel(text: l10n.settingsRecordingModeOff),
                    ),
                  ],
                  selected: {ref.watch(recordingModeProvider)},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    ref.read(recordingModeProvider.notifier).set(s.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Clip context (visible only when recording mode = detections)
              if (ref.watch(recordingModeProvider) == 'detections') ...[
                ListTile(
                  title: Text(l10n.surveyClipContext),
                  subtitle: Text(l10n.surveyClipContextDescription),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Slider(
                    value: ref.watch(clipContextProvider).toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: '\u00b1${ref.watch(clipContextProvider)}s',
                    onChanged:
                        (v) => ref
                            .read(clipContextProvider.notifier)
                            .set(v.round()),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Audio file format only matters when something is being
              // recorded; hiding it for mode = off avoids implying that the
              // setting has any effect.
              if (ref.watch(recordingModeProvider) != 'off')
                _ChoiceTile<String>(
                  title: l10n.settingsRecordingFormat,
                  helpBody: l10n.settingsHelpRecordingFormat,
                  value: ref.watch(recordingFormatProvider),
                  options: const {'wav': 'WAV', 'flac': 'FLAC'},
                  onChanged:
                      (v) => ref.read(recordingFormatProvider.notifier).set(v),
                ),
              // Auto-start tile is Live-only — the survey / point-count
              // setup wizards already gate session start behind their own
              // multi-step flows where an auto-start would skip required
              // configuration.
              if (settingsContext == SettingsContext.live ||
                  settingsContext == SettingsContext.all)
                SwitchListTile(
                  title: _TitleWithHelp(
                    title: l10n.settingsLiveAutoStart,
                    helpBody: l10n.settingsHelpLiveAutoStart,
                  ),
                  subtitle: Text(l10n.settingsLiveAutoStartDescription),
                  value: ref.watch(liveAutoStartProvider),
                  onChanged:
                      (v) => ref.read(liveAutoStartProvider.notifier).set(v),
                ),
              const Divider(),
            ],

            // --- Location / Geo ---
            if (_showSection('location')) ...[
              _SectionHeader(
                title: l10n.settingsLocation,
                subtitle: l10n.settingsLocationDescription,
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsUseGps,
                  helpBody: l10n.settingsHelpUseGps,
                ),
                subtitle: Text(l10n.settingsUseGpsDescription),
                value: ref.watch(useGpsProvider),
                onChanged: (v) => ref.read(useGpsProvider.notifier).set(v),
              ),
              if (!ref.watch(useGpsProvider)) ...[
                _SliderTile(
                  title: l10n.settingsLatitude,
                  value: ref.watch(manualLatitudeProvider),
                  min: -90,
                  max: 90,
                  divisions: 1800,
                  format: (v) => v.toStringAsFixed(2),
                  onChanged:
                      (v) => ref.read(manualLatitudeProvider.notifier).set(v),
                ),
                _SliderTile(
                  title: l10n.settingsLongitude,
                  value: ref.watch(manualLongitudeProvider),
                  min: -180,
                  max: 180,
                  divisions: 3600,
                  format: (v) => v.toStringAsFixed(2),
                  onChanged:
                      (v) => ref.read(manualLongitudeProvider.notifier).set(v),
                ),
              ],
              if (ref.watch(useGpsProvider)) const _GpsRefreshTile(),
              if (_showOfflineMapDownloadSetting && ref.watch(useGpsProvider))
                const OfflineMapDownloadTile(),
              _ChoiceTile<String>(
                title: l10n.settingsSpeciesFilter,
                helpBody: l10n.settingsHelpSpeciesFilter,
                value: ref.watch(speciesFilterModeProvider),
                options: {
                  'off': l10n.settingsFilterOff,
                  'geoExclude': l10n.settingsFilterGeoExclude,
                  'geoMerge': l10n.settingsFilterGeoMerge,
                },
                onChanged:
                    (v) => ref.read(speciesFilterModeProvider.notifier).set(v),
              ),
              if (ref.watch(speciesFilterModeProvider) != 'off')
                _SliderTile(
                  title: l10n.settingsGeoThreshold,
                  helpBody: l10n.settingsHelpGeoThreshold,
                  value: ref.watch(geoThresholdProvider),
                  min: 0.0,
                  max: 0.5,
                  divisions: 50,
                  format: (v) => v.toStringAsFixed(2),
                  onChanged:
                      (v) => ref.read(geoThresholdProvider.notifier).set(v),
                ),
              const Divider(),
            ],

            // --- Export ---
            if (_showSection('export')) ...[
              _SectionHeader(
                title: l10n.settingsExport,
                subtitle: l10n.settingsExportDescription,
              ),
              _ExportFormatChecklist(),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsIncludeAudioFiles,
                  helpBody: l10n.settingsHelpIncludeAudioFiles,
                ),
                value: ref.watch(includeAudioProvider),
                onChanged:
                    (v) => ref.read(includeAudioProvider.notifier).set(v),
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsExportHtmlReport,
                  helpBody: l10n.settingsHelpExportHtmlReport,
                ),
                value: ref.watch(exportHtmlReportProvider),
                onChanged:
                    (v) => ref.read(exportHtmlReportProvider.notifier).set(v),
              ),
              const Divider(),
            ],

            // --- Privacy ---
            if (_showSection('privacy')) ...[
              _SectionHeader(
                title: l10n.settingsPrivacy,
                subtitle: l10n.settingsPrivacyDescription,
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsPrivacyAllowMap,
                  helpBody: l10n.settingsHelpPrivacyAllowMap,
                ),
                subtitle: Text(l10n.settingsPrivacyAllowMapSubtitle),
                value: ref.watch(privacyAllowMapProvider),
                onChanged:
                    (v) => ref.read(privacyAllowMapProvider.notifier).set(v),
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsPrivacyAllowReverseGeocoding,
                  helpBody: l10n.settingsHelpPrivacyAllowReverseGeocoding,
                ),
                subtitle: Text(
                  l10n.settingsPrivacyAllowReverseGeocodingSubtitle,
                ),
                value: ref.watch(privacyAllowReverseGeocodingProvider),
                onChanged:
                    (v) => ref
                        .read(privacyAllowReverseGeocodingProvider.notifier)
                        .set(v),
              ),
              SwitchListTile(
                title: _TitleWithHelp(
                  title: l10n.settingsPrivacyAllowWeather,
                  helpBody: l10n.settingsHelpPrivacyAllowWeather,
                ),
                subtitle: Text(l10n.settingsPrivacyAllowWeatherSubtitle),
                value: ref.watch(privacyAllowWeatherProvider),
                onChanged:
                    (v) =>
                        ref.read(privacyAllowWeatherProvider.notifier).set(v),
              ),
              const Divider(),
            ],

            // --- Announcements ---
            // Section moved up: it now renders right after Spectrogram
            // (see above). Kept the comment marker here as a redirect
            // breadcrumb so future readers searching for it find the
            // new location.

            // --- About ---
            if (_showSection('about'))
              ListTile(
                title: Text(l10n.about),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),

            // --- Danger Zone ---
            if (_showSection('general')) ...[
              const Divider(),
              _SectionHeader(
                title: l10n.settingsDangerZone,
                subtitle: l10n.settingsDangerZoneDescription,
              ),
              ListTile(
                title: Text(l10n.settingsResetOnboarding),
                onTap: () => _showResetOnboardingDialog(context, ref, l10n),
              ),
              ListTile(
                title: Text(l10n.settingsResetAll),
                subtitle: Text(l10n.settingsResetAllSubtitle),
                onTap: () => _showResetAllSettingsDialog(context, l10n),
              ),
              ListTile(
                title: Text(
                  l10n.settingsClearData,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => _showClearDataDialog(context, l10n),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showResetOnboardingDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsResetOnboardingConfirmTitle),
            content: Text(l10n.settingsResetOnboardingConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  ref.read(onboardingCompleteProvider.notifier).reset();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsOnboardingReset)),
                  );
                },
                child: Text(l10n.confirm),
              ),
            ],
          ),
    );
  }

  void _showResetAllSettingsDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.settingsResetAllConfirmTitle),
          content: Text(l10n.settingsResetAllConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(dialogContext).pop();
                // Clear every persisted preference. Sessions, recordings,
                // voice memos and downloaded map tiles live outside of
                // SharedPreferences and are intentionally untouched.
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.settingsResetAllDone)),
                );
                // On Android we close the app so the next launch boots
                // with the freshly-reset defaults applied to every
                // provider. Other platforms leave the app running and
                // rely on the user to relaunch manually.
                await Future<void>.delayed(const Duration(milliseconds: 800));
                await SystemNavigator.pop();
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        var isClearing = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final typed = controller.text.trim().toUpperCase() == 'DELETE';
            return AlertDialog(
              title: Text(l10n.settingsClearDataConfirmTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsClearDataConfirmMessage),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    onChanged: (_) => setState(() {}),
                    enabled: !isClearing,
                    decoration: InputDecoration(
                      labelText: l10n.settingsClearDataTypeConfirm,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isClearing ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton.tonal(
                  onPressed:
                      typed && !isClearing
                          ? () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => isClearing = true);
                            try {
                              await const AppDataClearService().clearAllData();
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.settingsDataCleared),
                                ),
                              );
                              await Future<void>.delayed(
                                const Duration(milliseconds: 800),
                              );
                              await SystemNavigator.pop();
                            } catch (_) {
                              if (!context.mounted) return;
                              setState(() => isClearing = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.settingsDataClearFailed),
                                ),
                              );
                            }
                          }
                          : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child:
                      isClearing
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline title row that appends a small "?" help button when [helpBody]
/// is provided. Tap opens [showHelpSheet] with the same [title] and the
/// localized explanatory paragraph.
///
/// When [helpBody] is null, falls back to a plain `Text(title)` so the
/// surrounding layout stays identical for settings without help text.
class _TitleWithHelp extends StatelessWidget {
  const _TitleWithHelp({required this.title, this.helpBody});

  final String title;
  final String? helpBody;

  @override
  Widget build(BuildContext context) {
    if (helpBody == null) return Text(title);
    return Row(
      children: [
        Flexible(child: Text(title)),
        const SizedBox(width: 4),
        _HelpIconButton(title: title, body: helpBody!),
      ],
    );
  }
}

/// Compact info-icon button that opens a settings help bottom sheet.
class _HelpIconButton extends StatelessWidget {
  const _HelpIconButton({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(AppIcons.helpOutline, size: 18),
      visualDensity: VisualDensity.compact,
      tooltip: l10n.settingsHelpTooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: () => showSettingHelpSheet(context, title: title, body: body),
    );
  }
}

/// Show a Material 3 modal bottom sheet with a setting's help text.
///
/// Centralized here so the styling (handle, padding, typography) stays
/// consistent across all per-setting help affordances.
Future<void> showSettingHelpSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      title: Text(l10n.settingsTheme),
      trailing: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text(l10n.settingsThemeDark),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(l10n.settingsThemeLight),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(l10n.settingsThemeSystem),
          ),
        ],
        selected: {themeMode},
        onSelectionChanged: (selected) {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return ListTile(
      title: Text(l10n.settingsAppLanguage),
      trailing: DropdownButton<String?>(
        value: locale?.languageCode,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: null, child: Text('System')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
          DropdownMenuItem(value: 'fr', child: Text('Français')),
          DropdownMenuItem(value: 'es', child: Text('Español')),
          DropdownMenuItem(value: 'cs', child: Text('Čeština')),
          DropdownMenuItem(value: 'pt', child: Text('Português')),
          DropdownMenuItem(value: 'it', child: Text('Italiano')),
        ],
        onChanged: (value) {
          ref
              .read(localeProvider.notifier)
              .setLocale(value == null ? null : Locale(value));
        },
      ),
    );
  }
}

/// Available species name locales (code → native name).
const _speciesLanguages = <String, String>{
  'system': '', // placeholder — label comes from l10n
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'ru': 'Русский',
  'ja': '日本語',
  'cs': 'Čeština',
  'pt': 'Português',
  'ca': 'Català',
  'no': 'Norsk',
  'bg': 'Български',
  'sv': 'Svenska',
  'da': 'Dansk',
  'zh-CN': '中文 (简体)',
  'tr': 'Türkçe',
  'sk': 'Slovenčina',
  'sr': 'Српски',
  'uk': 'Українська',
  'fi': 'Suomi',
  'es_ES': 'Español (España)',
  'es_MX': 'Español (México)',
  'es_EC': 'Español (Ecuador)',
  'pt_PT': 'Português (Portugal)',
  'hr': 'Hrvatski',
  'lt': 'Lietuvių',
  'fa': 'فارسی',
  'cy': 'Cymraeg',
  'et': 'Eesti',
};

class _SpeciesLanguageTile extends ConsumerWidget {
  const _SpeciesLanguageTile({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesLang = ref.watch(speciesLanguageProvider);

    return ListTile(
      title: Text(l10n.settingsSpeciesLanguage),
      trailing: DropdownButton<String>(
        value: speciesLang,
        underline: const SizedBox.shrink(),
        items:
            _speciesLanguages.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.key == 'system'
                      ? l10n.settingsSpeciesLanguageSystem
                      : e.value,
                ),
              );
            }).toList(),
        onChanged: (value) {
          if (value != null) {
            ref.read(speciesLanguageProvider.notifier).set(value);
          }
        },
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.helpBody,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final String? helpBody;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: _TitleWithHelp(title: title, helpBody: helpBody),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: format(value),
        onChanged: onChanged,
      ),
      trailing: Text(
        format(value),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helpBody,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String? helpBody;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: _TitleWithHelp(title: title, helpBody: helpBody),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items:
            options.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Variant of [_ChoiceTile] for color-map selection that shows a small
/// gradient swatch next to each option's label, both in the closed dropdown
/// and in the expanded menu.
class _ColorMapChoiceTile extends StatelessWidget {
  const _ColorMapChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helpBody,
  });

  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final String? helpBody;

  /// Build a horizontal gradient strip from the named color map's LUT.
  Widget _swatch(String name, {double width = 56, double height = 14}) {
    final stops = List<double>.generate(11, (i) => i / 10);
    final colors =
        stops.map((s) => SpectrogramColorMap.color(name, s)).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, stops: stops),
        ),
      ),
    );
  }

  Widget _row(String name, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_swatch(name), const SizedBox(width: 10), Text(label)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: _TitleWithHelp(title: title, helpBody: helpBody),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        selectedItemBuilder:
            (_) =>
                options.entries
                    .map((e) => Center(child: _row(e.key, e.value)))
                    .toList(),
        items:
            options.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: _row(e.key, e.value),
                  ),
                )
                .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Dropdown that lists available audio input devices.
///
/// Uses [inputDevicesProvider] (async) to fetch the device list and
/// [selectedDeviceProvider] to track the current selection.
class _MicInputTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(inputDevicesProvider);
    final selected = ref.watch(selectedDeviceProvider);

    final l10n = AppLocalizations.of(context)!;

    return devicesAsync.when(
      loading:
          () => ListTile(
            title: Text(l10n.settingsMicrophone),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (a, b) => ListTile(
            title: Text(l10n.settingsMicrophone),
            trailing: Text(l10n.statusError),
          ),
      data: (devices) {
        // Find the label for the currently selected device.
        final selectedLabel =
            selected == null
                ? l10n.settingsSystemDefault
                : devices
                        .where((d) => d.id == selected)
                        .map((d) => d.label.isEmpty ? d.id : d.label)
                        .firstOrNull ??
                    selected;

        return ListTile(
          title: Text(l10n.settingsMicrophone),
          trailing: Text(
            selectedLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => _showDevicePicker(context, ref, devices, selected),
        );
      },
    );
  }

  void _showDevicePicker(
    BuildContext context,
    WidgetRef ref,
    List<InputDeviceInfo> devices,
    String? selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: RadioGroup<String?>(
            groupValue: selected,
            onChanged: (v) {
              ref.read(selectedDeviceProvider.notifier).state = v;
              Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    AppLocalizations.of(context)!.settingsSelectMicrophone,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                RadioListTile<String?>(
                  title: Text(
                    AppLocalizations.of(context)!.settingsSystemDefault,
                  ),
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
        );
      },
    );
  }
}

/// Two-line auto-shrinking label for a [SegmentedButton] segment.
///
/// Some locales (notably German "Nur Detektionen" and French
/// "Détections uniquement") overflow the default single-line label when
/// three segments share the row. Allowing two lines plus a small
/// font-scale fallback keeps every locale legible without forcing tiny
/// fixed text everywhere.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, height: 1.1),
    );
  }
}

// ---------------------------------------------------------------------------
// _GpsRefreshTile — manual "Refresh GPS now" entry in the Location section
// ---------------------------------------------------------------------------
//
// Forces the location service to fetch a fresh fix instead of using the
// FutureProvider-cached value. Useful when the user has moved since last
// open (the cached value can be miles away) or when they just want to
// verify the receiver is working.  We also surface the current cached
// coordinates as the subtitle so users can see at a glance what the app
// thinks their location is right now.
// ---------------------------------------------------------------------------

class _GpsRefreshTile extends ConsumerStatefulWidget {
  const _GpsRefreshTile();

  @override
  ConsumerState<_GpsRefreshTile> createState() => _GpsRefreshTileState();
}

class _GpsRefreshTileState extends ConsumerState<_GpsRefreshTile> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      ref.invalidate(currentLocationProvider);
      final location = await ref.read(currentLocationProvider.future);
      if (!mounted) return;
      final svc = ref.read(locationServiceProvider);
      final String message;
      if (location == null) {
        message = l10n.settingsGpsRefreshFailed;
      } else if (svc.lastFetchUsedCachedFallback) {
        message = l10n.gpsStaleWarning;
      } else {
        message = l10n.settingsGpsRefreshed;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.settingsGpsRefreshFailed),
            duration: const Duration(seconds: 3),
          ),
        );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loc = ref.watch(currentLocationProvider).value;
    final subtitle =
        _refreshing
            ? l10n.settingsGpsRefreshing
            : loc == null
            ? l10n.settingsGpsRefreshSubtitle
            : '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
    return ListTile(
      leading: const Icon(AppIcons.myLocation),
      title: Text(l10n.settingsGpsRefresh),
      subtitle: Text(subtitle),
      trailing:
          _refreshing
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(AppIcons.refresh),
      onTap: _refreshing ? null : _refresh,
    );
  }
}

// ---------------------------------------------------------------------------
// _ExportFormatChecklist — multi-select export formats (I2)
// ---------------------------------------------------------------------------
//
// Replaces the single-choice export-format selector with a row of
// independent toggles. The pipeline now bundles every enabled format
// into the export ZIP, so users can grab Raven + CSV + JSON in one
// share. Selection is persisted via [exportSelectionProvider]; an empty
// selection silently falls back to `{raven}` so the export always
// produces at least one document.
// ---------------------------------------------------------------------------

class _ExportFormatChecklist extends ConsumerWidget {
  const _ExportFormatChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selection = ref.watch(exportSelectionProvider);
    const formats = <(String, String)>[
      ('raven', 'Raven Selection Table'),
      ('csv', 'CSV'),
      ('json', 'JSON'),
      ('gpx', 'GPX (track + waypoints)'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _TitleWithHelp(
            title: l10n.settingsExportFormat,
            helpBody: l10n.settingsHelpExportFormat,
          ),
        ),
        for (final fmt in formats)
          CheckboxListTile(
            dense: true,
            title: Text(fmt.$2),
            value: selection.contains(fmt.$1),
            onChanged:
                (v) => ref
                    .read(exportSelectionProvider.notifier)
                    .toggle(fmt.$1, v ?? false),
          ),
      ],
    );
  }
}
