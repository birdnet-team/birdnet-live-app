import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/app_icons.dart';
import '../audio_providers.dart';

// =============================================================================
// Audio Source Tile — the single picker, shared by every screen that has one
// =============================================================================
//
// Settings, Survey setup, Point Count setup and ARU setup all offer the same
// choice, so they all render [AudioSourceTile] and open the same bottom sheet.
// The tile only varies cosmetically (leading icon, where the value sits), which
// the constructor exposes; the option list and its wording live here, once.
//
// ### Why one sheet with two controls
//
// Device and processing are orthogonal on Android: the audio source goes into
// the `AudioRecord` constructor, the device into `setPreferredDevice()`. Every
// combination is legal — a USB mic captured unprocessed is both reachable and
// desirable. Folding them into a single flat radio list would silently make
// them mutually exclusive, so the sheet keeps them as two controls: processing
// on top, microphone below.
//
// This matters more than it first appears, because Android reports each
// built-in mic (bottom, back, …) as its own device on many handsets. Under a
// folded model, choosing "built-in mic (back)" would quietly re-enable the very
// voice DSP this feature exists to escape.
//
// On platforms without selectable processing (see [audioSourceProfilesSupported])
// the top control is hidden and the sheet degrades to a plain device picker.
// =============================================================================

/// Where the tile shows the currently selected source.
enum AudioSourceValuePlacement {
  /// Right-aligned on the same row as the title. Used where the tile sits in a
  /// dense list of settings rows.
  trailing,

  /// Below the title, with a chevron on the right. Used where the tile is a
  /// tappable navigation-style row.
  subtitle,
}

/// Tile that shows the selected audio source and opens the picker on tap.
class AudioSourceTile extends ConsumerWidget {
  const AudioSourceTile({
    super.key,
    this.leading,
    this.contentPadding,
    this.placement = AudioSourceValuePlacement.trailing,
  });

  /// Leading widget, typically a mic icon. Omitted in Settings, where the
  /// surrounding rows have no icons either.
  final Widget? leading;

  final EdgeInsetsGeometry? contentPadding;

  final AudioSourceValuePlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(inputDevicesProvider);
    final selection = ref.watch(audioSourceProvider);

    return devicesAsync.when(
      loading: () => ListTile(
        leading: leading,
        contentPadding: contentPadding,
        title: _AudioSourceTitle(l10n: l10n),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      // Processing doesn't depend on device enumeration, but a failure here
      // means we can't name the selected device, so fall back to the label we
      // can always produce.
      error: (_, _) => ListTile(
        leading: leading,
        contentPadding: contentPadding,
        title: _AudioSourceTitle(l10n: l10n),
        subtitle: Text(audioSourceLabel(l10n, const [], selection)),
      ),
      data: (devices) {
        final label = audioSourceLabel(l10n, devices, selection);
        final isSubtitle = placement == AudioSourceValuePlacement.subtitle;

        return ListTile(
          leading: leading,
          contentPadding: contentPadding,
          title: _AudioSourceTitle(l10n: l10n),
          subtitle: isSubtitle ? Text(label) : null,
          // Always end the row with a chevron. Without it the row reads as a
          // static "label: value" line and nobody discovers it is tappable —
          // which is how the old microphone row behaved.
          trailing: isSubtitle
              ? const Icon(AppIcons.chevronRight)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cap the value so a long device name can't squeeze the
                    // title out of the row.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
          onTap: () => showAudioSourcePicker(context, ref, devices),
        );
      },
    );
  }
}

class _AudioSourceTitle extends StatelessWidget {
  const _AudioSourceTitle({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(l10n.settingsAudioSource)),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(AppIcons.helpOutline, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: l10n.settingsHelpTooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            useSafeArea: true,
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsAudioSource,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsHelpAudioSource,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Human-readable name of [selection], for a tile or a summary row.
///
/// Names only the parts that differ from the default, so the common cases stay
/// short: "Unprocessed", or "USB Audio CODEC", rather than always spelling out
/// both halves. Both are shown only when both were actually chosen.
String audioSourceLabel(
  AppLocalizations l10n,
  List<InputDeviceInfo> devices,
  AudioSourceSelection selection,
) {
  final deviceId = selection.deviceId;
  final isDefaultProfile =
      selection.profile == AudioSourceProfile.systemDefault;

  if (deviceId == null) {
    return isDefaultProfile
        ? l10n.settingsSystemDefault
        : _profileTitle(l10n, selection.profile);
  }

  // Fall back to the raw ID for a device that is no longer connected — better
  // than implying we're on the default mic when we aren't.
  final device =
      devices
          .where((d) => d.id == deviceId)
          .map((d) => d.label.isEmpty ? d.id : d.label)
          .firstOrNull ??
      deviceId;

  if (isDefaultProfile) return device;
  return '$device · ${_profileTitle(l10n, selection.profile)}';
}

/// Open the audio source picker.
///
/// The sheet writes straight through to [audioSourceProvider] on every change
/// and stays open, so both controls can be set in one visit — and because a
/// change applies to a running session immediately, the effect is audible while
/// the sheet is still up. Dismissed by the drag handle or the scrim.
void showAudioSourcePicker(
  BuildContext context,
  WidgetRef ref,
  List<InputDeviceInfo> devices,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final theme = Theme.of(sheetContext);

      return SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final selection = ref.watch(audioSourceProvider);
            final notifier = ref.read(audioSourceProvider.notifier);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                    child: Text(
                      l10n.settingsSelectAudioSource,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (audioSourceProfilesSupported) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        l10n.audioSourcePickerHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _SectionHeader(label: l10n.audioSourceProcessing),
                    // A vertical radio group rather than a SegmentedButton:
                    // three segments sharing one row cannot fit the profile
                    // names in several locales (German "Spracherkennung",
                    // Russian "Распознавание речи") and would ellipsize them.
                    // Stacking also lets every option show its description,
                    // instead of only the selected one.
                    RadioGroup<AudioSourceProfile>(
                      groupValue: selection.profile,
                      onChanged: (profile) {
                        if (profile == null) return;
                        notifier.state = selection.withProfile(profile);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final profile in AudioSourceProfile.values)
                            RadioListTile<AudioSourceProfile>(
                              value: profile,
                              title: Text(_profileTitle(l10n, profile)),
                              subtitle: Text(
                                _profileDescription(l10n, profile),
                              ),
                              isThreeLine: true,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    _SectionHeader(label: l10n.audioSourceMicrophone),
                  ] else
                    // Without a processing control the device list is the only
                    // section, so a header would just be noise: the sheet is
                    // simply a microphone picker, as it has always been here.
                    const SizedBox(height: 8),

                  RadioGroup<String?>(
                    groupValue: selection.deviceId,
                    onChanged: (deviceId) =>
                        notifier.state = selection.withDevice(deviceId),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String?>(
                          value: null,
                          title: Text(l10n.settingsSystemDefault),
                        ),
                        ...devices.map(
                          (device) => RadioListTile<String?>(
                            value: device.id,
                            title: Text(
                              device.label.isEmpty ? device.id : device.label,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

String _profileTitle(AppLocalizations l10n, AudioSourceProfile profile) {
  switch (profile) {
    case AudioSourceProfile.systemDefault:
      return l10n.audioSourceProcessingDefault;
    case AudioSourceProfile.unprocessed:
      return l10n.audioSourceUnprocessed;
    case AudioSourceProfile.voiceRecognition:
      return l10n.audioSourceVoiceRecognition;
  }
}

String _profileDescription(AppLocalizations l10n, AudioSourceProfile profile) {
  switch (profile) {
    case AudioSourceProfile.systemDefault:
      return l10n.audioSourceSystemDefaultDescription;
    case AudioSourceProfile.unprocessed:
      return l10n.audioSourceUnprocessedDescription;
    case AudioSourceProfile.voiceRecognition:
      return l10n.audioSourceVoiceRecognitionDescription;
  }
}
