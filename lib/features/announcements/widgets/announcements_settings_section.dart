// =============================================================================
// AnnouncementsSettingsSection
// =============================================================================
//
// The Settings → Announcements section. Pulled into its own file (rather
// than dropped inline into settings_screen.dart) because it owns a small
// cluster of interacting controls — master toggle, two "what it says"
// pickers (verbosity + frequency), a Voice group (voice picker, speed,
// pitch, sample preview) and an "Advanced" disclosure.
//
// Layout notes (the reason this was reworked):
//   * Every label/value pair is laid out so it can never overflow on
//     locales with long strings — labels use `Expanded`/`Wrap`, not the
//     fixed-width `SizedBox`es the old version used. German ("Pitch" →
//     "Tonhöhe", "Speed" → "Geschwindigkeit") no longer clips.
//   * Verbosity is a wrapping `ChoiceChip` row instead of a fixed-width
//     `SegmentedButton`, which cannot wrap and overflowed for long
//     option labels.
//
// The numeric throttling knobs (startup grace, min interval, max per
// minute, streak silence, recency reset, session reset, coalesce window)
// are intentionally NOT exposed — they are stamped automatically by the
// frequency slider via `frequencyProfileFor()`.
// =============================================================================

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/utils/app_icons.dart';
import '../announcements_providers.dart';
import '../domain/announcement_presets.dart';
import '../domain/announcement_signals.dart';
import '../phrasing/phrasing_engine.dart';
import '../phrasing/template_library.dart';
import '../platform/tts_engine.dart';

/// Resolve which BCP-47 language the voice should use, mirroring the
/// alert-sink's resolution order: explicit override → species-name
/// locale → platform locale. Kept in the settings layer so the voice
/// picker and preview enumerate/speak in the same voice the live
/// announcements will use.
String _resolveVoiceLanguage(WidgetRef ref) {
  final pref = ref.read(announcementsVoiceLanguageProvider);
  if (pref.isNotEmpty) return pref;
  final species = ref.read(effectiveSpeciesLocaleProvider);
  if (species.isNotEmpty) return species;
  return ui.PlatformDispatcher.instance.locale.toLanguageTag();
}

/// Settings section for the Announcements feature.
///
/// Returns a `Column` with a [Divider] at the bottom so it drops into
/// existing Settings layouts without further wrapping.
class AnnouncementsSettingsSection extends ConsumerWidget {
  const AnnouncementsSettingsSection({
    super.key,
    required this.sectionHeader,
    required this.titleWithHelp,
  });

  /// Builder for the small section header used in `settings_screen.dart`.
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
          _VoiceGroup(titleWithHelp: titleWithHelp),
          _AdvancedDisclosure(titleWithHelp: titleWithHelp),
        ],
        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verbosity — wrapping choice chips (locale-safe)
// ---------------------------------------------------------------------------

class _VerbosityPicker extends ConsumerWidget {
  const _VerbosityPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsVerbosityProvider);

    String labelFor(AnnouncementVerbosity v) {
      switch (v) {
        case AnnouncementVerbosity.minimal:
          return l10n.settingsAnnouncementsVerbosityMinimal;
        case AnnouncementVerbosity.balanced:
          return l10n.settingsAnnouncementsVerbosityBalanced;
        case AnnouncementVerbosity.chatty:
          return l10n.settingsAnnouncementsVerbosityChatty;
        case AnnouncementVerbosity.custom:
          return l10n.settingsAnnouncementsVerbosityCustom;
      }
    }

    const options = [
      AnnouncementVerbosity.minimal,
      AnnouncementVerbosity.balanced,
      AnnouncementVerbosity.chatty,
    ];
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(labelFor(o)),
                  selected: value == o,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(announcementsVerbosityProvider.notifier).set(o);
                    }
                  },
                ),
              // Older builds could persist a `custom` verbosity; surface
              // it as a selected chip so the UI never lies, but don't let
              // the user pick it directly (there's no custom template
              // authoring surface).
              if (value == AnnouncementVerbosity.custom)
                ChoiceChip(
                  label: Text(labelFor(AnnouncementVerbosity.custom)),
                  selected: true,
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Frequency — 5-step slider (shows one label at a time, locale-safe)
// ---------------------------------------------------------------------------

class _FrequencyPicker extends ConsumerWidget {
  const _FrequencyPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsFrequencyProvider);
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
          child: Center(
            child: Text(
              labelFor(value),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Semantics(
            label: l10n.settingsAnnouncementsFrequency,
            value: labelFor(presets[sliderPos.round()]),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.settingsAnnouncementsFrequencyRare,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Flexible(
                child: Text(
                  l10n.settingsAnnouncementsFrequencyConstant,
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice group — picker + speed + pitch + preview
// ---------------------------------------------------------------------------

class _VoiceGroup extends ConsumerWidget {
  const _VoiceGroup({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final voiceName = ref.watch(announcementsVoiceNameProvider);
    final rate = ref.watch(announcementsVoiceRateProvider);
    final pitch = ref.watch(announcementsVoicePitchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(AppIcons.campaign),
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsVoice,
            helpBody: l10n.settingsHelpAnnouncementsVoice,
          ),
          subtitle: Text(
            voiceName.isEmpty
                ? l10n.settingsAnnouncementsVoiceDefault
                : voiceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: () => _showVoicePicker(context, ref),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            children: [
              _LabeledSlider(
                label: l10n.settingsAnnouncementsVoiceRate,
                value: rate,
                min: 0.5,
                max: 1.5,
                divisions: 10,
                display: '${rate.toStringAsFixed(2)}×',
                onChanged:
                    (v) => ref
                        .read(announcementsVoiceRateProvider.notifier)
                        .set(v),
              ),
              _LabeledSlider(
                label: l10n.settingsAnnouncementsVoicePitch,
                value: pitch,
                min: 0.7,
                max: 1.3,
                divisions: 6,
                display: pitch.toStringAsFixed(2),
                onChanged:
                    (v) => ref
                        .read(announcementsVoicePitchProvider.notifier)
                        .set(v),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(AppIcons.volumeUpOutlined),
              label: Text(l10n.settingsAnnouncementsPreview),
              onPressed: () => _speakPreview(ref, l10n),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showVoicePicker(BuildContext context, WidgetRef ref) async {
    final languageTag = _resolveVoiceLanguage(ref);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VoicePickerSheet(languageTag: languageTag),
    );
  }

  Future<void> _speakPreview(WidgetRef ref, AppLocalizations l10n) async {
    final tts = FlutterTtsEngine();
    try {
      final lang = _resolveVoiceLanguage(ref);
      final verbosity = ref.read(announcementsVerbosityProvider);
      await tts.configure(
        languageTag: lang,
        rate: ref.read(announcementsVoiceRateProvider),
        pitch: ref.read(announcementsVoicePitchProvider),
        voiceName: ref.read(announcementsVoiceNameProvider),
      );
      // Preview both the chosen voice AND the current phrasing style by
      // running the real engine on a couple of sample detections.
      final bundle = await TemplateLibrary().load(lang);
      final engine = PhrasingEngine(bundle: bundle);
      final one = engine.speakOne(
        name: l10n.announcementsSampleSpecies1,
        signals: const AnnouncementSignals(
          confidence: ConfidenceBin.high,
          isRecent: false,
          isFirstInSession: true,
          streakLength: 1,
        ),
        verbosity: verbosity,
      );
      final many = engine.speakMany(
        names: [
          l10n.announcementsSampleSpecies1,
          l10n.announcementsSampleSpecies2,
          l10n.announcementsSampleSpecies3,
        ],
        verbosity: verbosity,
      );
      await tts.speak('$one $many');
    } catch (_) {
      // Preview is best-effort — a TTS hiccup here shouldn't surface an
      // error to the user.
    } finally {
      await tts.dispose();
    }
  }
}

/// Label + value row above a full-width slider. Never overflows because
/// the label expands and wraps instead of living in a fixed-width box.
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Text(
                display,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: label,
          value: display,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice picker sheet
// ---------------------------------------------------------------------------

class _VoicePickerSheet extends ConsumerStatefulWidget {
  const _VoicePickerSheet({required this.languageTag});

  final String languageTag;

  @override
  ConsumerState<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends ConsumerState<_VoicePickerSheet> {
  FlutterTtsEngine? _engine;
  late Future<List<TtsVoice>> _voices;

  @override
  void initState() {
    super.initState();
    final engine = FlutterTtsEngine();
    _engine = engine;
    _voices = engine.voicesForLanguage(widget.languageTag);
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final current = ref.watch(announcementsVoiceNameProvider);
    return SafeArea(
      child: FutureBuilder<List<TtsVoice>>(
        future: _voices,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final voices = snapshot.data ?? const <TtsVoice>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.settingsAnnouncementsVoicePickTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: RadioGroup<String>(
                    groupValue: current,
                    onChanged: (v) {
                      ref
                          .read(announcementsVoiceNameProvider.notifier)
                          .set(v ?? '');
                      Navigator.of(context).pop();
                    },
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        RadioListTile<String>(
                          value: '',
                          title: Text(l10n.settingsAnnouncementsVoiceDefault),
                        ),
                        for (final voice in voices)
                          RadioListTile<String>(
                            value: voice.name,
                            title: Text(
                              voice.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                voice.locale.isEmpty
                                    ? null
                                    : Text(voice.locale),
                          ),
                        if (voices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Text(
                              l10n.settingsAnnouncementsVoiceUnavailable,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
      ],
    );
  }
}
