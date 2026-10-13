import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/settings_providers.dart';

/// Note under an inference-rate slider once a live mode has had to lower the
/// rate: this device is known to be too slow above the rate it was lowered
/// to. Settings and every setup wizard show the same note, so the limit reads
/// the same wherever the rate can be set. Renders nothing while the device
/// has never fallen behind, and stays once it has — a slow device stays slow.
class InferenceRateLimitNote extends ConsumerWidget {
  const InferenceRateLimitNote({super.key, this.padding = EdgeInsets.zero});

  /// Inset to line the note up with the slider above it.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(inferenceRateDeviceLimitProvider);
    if (limit == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        AppLocalizations.of(context)!
            .settingsInferenceRateDeviceLimit(limit.toStringAsFixed(2)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
