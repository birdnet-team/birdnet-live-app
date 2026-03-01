import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../about/about_screen.dart';

/// Settings screen with categorized preferences.
///
/// Categories: Audio, Inference, Spectrogram, Recording, Export, General.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // --- General ---
          _SectionHeader(title: l10n.settingsGeneral),
          _ThemeTile(l10n: l10n),
          _LanguageTile(l10n: l10n),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.settingsResetOnboarding),
            onTap: () {
              ref.read(onboardingCompleteProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Onboarding will show on next launch')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              l10n.settingsClearData,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => _showClearDataDialog(context, ref, l10n),
          ),

          const Divider(),

          // --- Audio ---
          _SectionHeader(title: l10n.settingsAudio),
          _SliderTile(
            title: 'Gain',
            value: ref.watch(audioGainProvider),
            min: 0.0,
            max: 2.0,
            divisions: 20,
            format: (v) => v.toStringAsFixed(1),
            onChanged: (v) => ref.read(audioGainProvider.notifier).set(v),
          ),
          _SliderTile(
            title: 'High-pass filter (Hz)',
            value: ref.watch(highPassFilterProvider),
            min: 0,
            max: 500,
            divisions: 50,
            format: (v) => '${v.toInt()} Hz',
            onChanged: (v) => ref.read(highPassFilterProvider.notifier).set(v),
          ),

          const Divider(),

          // --- Inference ---
          _SectionHeader(title: l10n.settingsInference),
          _ChoiceTile<int>(
            title: 'Window duration',
            value: ref.watch(windowDurationProvider),
            options: const {3: '3s', 5: '5s', 10: '10s'},
            onChanged: (v) => ref.read(windowDurationProvider.notifier).set(v),
          ),
          _SliderTile(
            title: 'Confidence threshold',
            value: ref.watch(confidenceThresholdProvider).toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            format: (v) => '${v.toInt()}%',
            onChanged: (v) =>
                ref.read(confidenceThresholdProvider.notifier).set(v.toInt()),
          ),
          _ChoiceTile<double>(
            title: 'Inference rate',
            value: ref.watch(inferenceRateProvider),
            options: {0.25: '0.25 Hz', 0.5: '0.5 Hz', 1.0: '1 Hz', 2.0: '2 Hz'},
            onChanged: (v) => ref.read(inferenceRateProvider.notifier).set(v),
          ),

          const Divider(),

          // --- Spectrogram ---
          _SectionHeader(title: l10n.settingsSpectrogram),
          _ChoiceTile<int>(
            title: 'FFT size',
            value: ref.watch(fftSizeProvider),
            options: const {
              512: '512',
              1024: '1024',
              2048: '2048',
              4096: '4096'
            },
            onChanged: (v) => ref.read(fftSizeProvider.notifier).set(v),
          ),
          _ChoiceTile<String>(
            title: 'Color map',
            value: ref.watch(colorMapProvider),
            options: const {
              'viridis': 'Viridis',
              'magma': 'Magma',
              'grayscale': 'Grayscale',
            },
            onChanged: (v) => ref.read(colorMapProvider.notifier).set(v),
          ),
          _ChoiceTile<int>(
            title: 'Duration (scroll speed)',
            value: ref.watch(spectrogramDurationProvider),
            options: const {
              5: '5 s',
              10: '10 s',
              15: '15 s',
              20: '20 s',
              30: '30 s',
            },
            onChanged: (v) =>
                ref.read(spectrogramDurationProvider.notifier).set(v),
          ),
          _ChoiceTile<int>(
            title: 'Frequency range',
            value: ref.watch(spectrogramMaxFreqProvider),
            options: const {
              4000: '4 kHz',
              6000: '6 kHz',
              8000: '8 kHz',
              10000: '10 kHz',
              12000: '12 kHz',
              16000: '16 kHz',
            },
            onChanged: (v) =>
                ref.read(spectrogramMaxFreqProvider.notifier).set(v),
          ),

          const Divider(),

          // --- Recording ---
          _SectionHeader(title: l10n.settingsRecording),
          _ChoiceTile<String>(
            title: 'Format',
            value: ref.watch(recordingFormatProvider),
            options: const {'wav': 'WAV', 'flac': 'FLAC'},
            onChanged: (v) => ref.read(recordingFormatProvider.notifier).set(v),
          ),
          _ChoiceTile<String>(
            title: 'Mode',
            value: ref.watch(recordingModeProvider),
            options: const {
              'off': 'Off',
              'full': 'Full',
              'detections': 'Detections only'
            },
            onChanged: (v) => ref.read(recordingModeProvider.notifier).set(v),
          ),

          const Divider(),

          // --- Export ---
          _SectionHeader(title: l10n.settingsExport),
          _ChoiceTile<String>(
            title: 'Format',
            value: ref.watch(exportFormatProvider),
            options: const {'csv': 'CSV', 'json': 'JSON', 'gpx': 'GPX'},
            onChanged: (v) => ref.read(exportFormatProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: const Text('Include audio files'),
            value: ref.watch(includeAudioProvider),
            onChanged: (v) => ref.read(includeAudioProvider.notifier).set(v),
          ),

          const Divider(),

          // --- About ---
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showClearDataDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsClearDataConfirmTitle),
        content: Text(l10n.settingsClearDataConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              // TODO: Clear session database and recordings
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      leading: const Icon(Icons.brightness_6),
      title: Text(l10n.settingsTheme),
      trailing: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
              value: ThemeMode.dark, label: Text(l10n.settingsThemeDark)),
          ButtonSegment(
              value: ThemeMode.light, label: Text(l10n.settingsThemeLight)),
          ButtonSegment(
              value: ThemeMode.system, label: Text(l10n.settingsThemeSystem)),
        ],
        selected: {themeMode},
        onSelectionChanged: (selected) {
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
      leading: const Icon(Icons.language),
      title: Text(l10n.settingsLanguage),
      trailing: DropdownButton<String?>(
        value: locale?.languageCode,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: null, child: Text('System')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
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

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
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
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
