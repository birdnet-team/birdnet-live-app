// =============================================================================
// AnnouncementsSettingsSection
// =============================================================================
//
// The Settings → Announcements section. Pulled into its own file (rather
// than dropped inline into settings_screen.dart) because it owns about
// a dozen interacting widgets — master toggle, verbosity segmented
// button, frequency slider, two voice sliders, a preview button that
// drives the local TTS engine, and an "Advanced" disclosure with four
// routing/capture switches.
//
// Visibility / scope: this section is shown in the global Settings
// screen and from the per-mode Settings entries (Live, Survey, Point
// Count). There is no first-run setup wizard — the two preset pickers
// (verbosity × frequency) are intentionally the only knobs the user
// has to touch.
//
// All gating is done with [announcementsEnabledProvider]. The numeric
// throttling knobs (startup grace, min interval, max per minute,
// streak silence, recency reset, session reset, coalesce window) are
// intentionally NOT exposed in the UI — they are stamped automatically
// by the frequency slider via `frequencyProfileFor()`. Hiding them
// keeps the surface area small; power users with a `custom` profile
// saved from older builds still see their preset name (the slider
// thumb just parks at the closest preset visually).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../announcements_providers.dart';
import '../domain/announcement_presets.dart';
import '../platform/tts_engine.dart';

/// Settings section for the Announcements feature.
///
/// Renders nothing on the screen unless mounted inside a `ListView` /
/// `Column`. Returns a `Column` with a [Divider] at the bottom so it
/// drops into existing Settings layouts without further wrapping.
class AnnouncementsSettingsSection extends ConsumerWidget {
  const AnnouncementsSettingsSection({
    super.key,
    required this.sectionHeader,
    required this.titleWithHelp,
  });

  /// Builder for the small section header used in `settings_screen.dart`.
  /// Passed in so this widget does not have to import a private widget.
  final Widget Function({required String title, required String subtitle})
  sectionHeader;

  /// Builder for an inline title row with a "?" affordance.
  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(announcementsEnabledProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(
          title: l10n.settingsAnnouncements,
          subtitle: l10n.settingsAnnouncementsDescription,
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsEnabled,
            helpBody: l10n.settingsHelpAnnouncementsEnabled,
          ),
          subtitle: Text(l10n.settingsAnnouncementsEnabledSubtitle),
          value: enabled,
          onChanged:
              (v) => ref.read(announcementsEnabledProvider.notifier).set(v),
        ),
        if (enabled) ...[
          _VerbosityPicker(titleWithHelp: titleWithHelp),
          _FrequencyPicker(titleWithHelp: titleWithHelp),
          _VoiceSubsection(titleWithHelp: titleWithHelp),
          const _PreviewAndWizardRow(),
          _AdvancedDisclosure(titleWithHelp: titleWithHelp),
        ],
        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verbosity / Frequency segmented pickers
// ---------------------------------------------------------------------------

class _VerbosityPicker extends ConsumerWidget {
  const _VerbosityPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsVerbosityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsVerbosity,
            helpBody: l10n.settingsHelpAnnouncementsVerbosity,
          ),
          subtitle: Text(l10n.settingsAnnouncementsVerbosityDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<AnnouncementVerbosity>(
              segments: [
                ButtonSegment(
                  value: AnnouncementVerbosity.minimal,
                  label: Text(l10n.settingsAnnouncementsVerbosityMinimal),
                ),
                ButtonSegment(
                  value: AnnouncementVerbosity.balanced,
                  label: Text(l10n.settingsAnnouncementsVerbosityBalanced),
                ),
                ButtonSegment(
                  value: AnnouncementVerbosity.chatty,
                  label: Text(l10n.settingsAnnouncementsVerbosityChatty),
                ),
                if (value == AnnouncementVerbosity.custom)
                  ButtonSegment(
                    value: AnnouncementVerbosity.custom,
                    label: Text(l10n.settingsAnnouncementsVerbosityCustom),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (sel) {
                final v = sel.first;
                if (v == AnnouncementVerbosity.custom) return;
                ref.read(announcementsVerbosityProvider.notifier).set(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FrequencyPicker extends ConsumerWidget {
  const _FrequencyPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsFrequencyProvider);
    // Five presets sit on a 0..4 axis (rare → constant). Custom is
    // off-axis: when the user has tweaked an Advanced numeric the
    // slider thumb parks at the closest preset visually but the
    // selection label below shows "Custom" so the UI never lies.
    const presets = <AnnouncementFrequency>[
      AnnouncementFrequency.rare,
      AnnouncementFrequency.sparse,
      AnnouncementFrequency.normal,
      AnnouncementFrequency.frequent,
      AnnouncementFrequency.constant,
    ];
    String labelFor(AnnouncementFrequency f) {
      switch (f) {
        case AnnouncementFrequency.rare:
          return l10n.settingsAnnouncementsFrequencyRare;
        case AnnouncementFrequency.sparse:
          return l10n.settingsAnnouncementsFrequencySparse;
        case AnnouncementFrequency.normal:
          return l10n.settingsAnnouncementsFrequencyNormal;
        case AnnouncementFrequency.frequent:
          return l10n.settingsAnnouncementsFrequencyFrequent;
        case AnnouncementFrequency.constant:
          return l10n.settingsAnnouncementsFrequencyConstant;
        case AnnouncementFrequency.custom:
          return l10n.settingsAnnouncementsFrequencyCustom;
      }
    }

    final isCustom = value == AnnouncementFrequency.custom;
    // Slider position: when on a preset, snap to its index. When custom,
    // park at "normal" (the middle) so dragging just one notch lands on
    // a sensible nearby preset rather than jumping across the range.
    final sliderPos =
        isCustom
            ? presets.indexOf(AnnouncementFrequency.normal).toDouble()
            : presets.indexOf(value).toDouble();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsFrequency,
            helpBody: l10n.settingsHelpAnnouncementsFrequency,
          ),
          subtitle: Text(l10n.settingsAnnouncementsFrequencyDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                labelFor(value),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            min: 0,
            max: (presets.length - 1).toDouble(),
            divisions: presets.length - 1,
            value: sliderPos,
            label: labelFor(presets[sliderPos.round()]),
            onChanged: (raw) {
              final idx = raw.round().clamp(0, presets.length - 1);
              final next = presets[idx];
              if (next == value) return;
              ref.read(announcementsFrequencyProvider.notifier).set(next);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.settingsAnnouncementsFrequencyRare,
                style: theme.textTheme.labelSmall,
              ),
              Text(
                l10n.settingsAnnouncementsFrequencyConstant,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice subsection
// ---------------------------------------------------------------------------

class _VoiceSubsection extends ConsumerWidget {
  const _VoiceSubsection({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rate = ref.watch(announcementsVoiceRateProvider);
    final pitch = ref.watch(announcementsVoicePitchProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsAnnouncementsVoice,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _LabeledSlider(
            label: l10n.settingsAnnouncementsVoiceRate,
            value: rate,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            display: rate.toStringAsFixed(2),
            onChanged:
                (v) => ref.read(announcementsVoiceRateProvider.notifier).set(v),
          ),
          _LabeledSlider(
            label: l10n.settingsAnnouncementsVoicePitch,
            value: pitch,
            min: 0.7,
            max: 1.3,
            divisions: 6,
            display: pitch.toStringAsFixed(2),
            onChanged:
                (v) =>
                    ref.read(announcementsVoicePitchProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview button
// ---------------------------------------------------------------------------

class _PreviewAndWizardRow extends ConsumerWidget {
  const _PreviewAndWizardRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l10n.settingsAnnouncementsPreview),
            onPressed: () => _speakPreview(ref, l10n),
          ),
          // Setup wizard intentionally omitted — the verbosity ×
          // frequency pickers above are the entire setup. Users find
          // their sweet spot by tapping segments, no multi-step flow.
        ],
      ),
    );
  }

  Future<void> _speakPreview(WidgetRef ref, AppLocalizations l10n) async {
    final tts = FlutterTtsEngine();
    try {
      final lang = ref.read(announcementsVoiceLanguageProvider);
      final rate = ref.read(announcementsVoiceRateProvider);
      final pitch = ref.read(announcementsVoicePitchProvider);
      await tts.configure(
        languageTag: lang.isEmpty ? 'en-US' : lang,
        rate: rate,
        pitch: pitch,
      );
      final s1 = l10n.announcementsSampleSpecies1;
      final s2 = l10n.announcementsSampleSpecies2;
      final s3 = l10n.announcementsSampleSpecies3;
      await tts.speak('$s1. $s2. $s3.');
    } finally {
      await tts.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Advanced disclosure
// ---------------------------------------------------------------------------

class _AdvancedDisclosure extends ConsumerWidget {
  const _AdvancedDisclosure({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      title: Text(l10n.settingsAnnouncementsAdvanced),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsSpeakerOutputAllowed,
            helpBody: l10n.settingsHelpAnnouncementsSpeakerOutputAllowed,
          ),
          value: ref.watch(announcementsSpeakerOutputAllowedProvider),
          onChanged:
              (v) => ref
                  .read(announcementsSpeakerOutputAllowedProvider.notifier)
                  .set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsMuteCaptureDuringSpeech,
            helpBody: l10n.settingsHelpAnnouncementsMuteCaptureDuringSpeech,
          ),
          value: ref.watch(announcementsMuteCaptureDuringSpeechProvider),
          onChanged:
              (v) => ref
                  .read(announcementsMuteCaptureDuringSpeechProvider.notifier)
                  .set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsDuckOtherAudio,
            helpBody: l10n.settingsHelpAnnouncementsDuckOtherAudio,
          ),
          value: ref.watch(announcementsDuckOtherAudioProvider),
          onChanged:
              (v) =>
                  ref.read(announcementsDuckOtherAudioProvider.notifier).set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsPrerollCue,
            helpBody: l10n.settingsHelpAnnouncementsPrerollCue,
          ),
          value: ref.watch(announcementsPrerollCueProvider),
          onChanged:
              (v) => ref.read(announcementsPrerollCueProvider.notifier).set(v),
        ),
        // Throttling numerics (startup grace, min interval, max per
        // minute, streak silence, recency / session reset, coalesce
        // window) are intentionally hidden — they are stamped by the
        // frequency slider above and rarely need per-knob tweaking.
      ],
    );
  }
}
