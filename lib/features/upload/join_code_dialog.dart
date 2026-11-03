// =============================================================================
// Join Code Dialog — a destination's join link as a QR code
// =============================================================================
//
// Shown from a destination's screen so a second phone can scan it with its
// camera. The code carries the secret by design; the body text says so.
//
// Layout note: AlertDialog measures its content with IntrinsicWidth, and
// QrImageView builds through a LayoutBuilder, which cannot report intrinsic
// dimensions. Without the fixed-size box around it the dialog never lays out
// and the framework asserts on every frame ("Cannot hit test a render box
// with no size", "!semantics.parentDataDirty"). Keep the SizedBox.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/utils/app_icons.dart';

class JoinCodeDialog extends StatelessWidget {
  const JoinCodeDialog({super.key, required this.link, required this.onCopy});

  /// The join link to encode and copy.
  final String link;

  /// Called after the link was copied; the dialog pops itself first.
  final VoidCallback onCopy;

  /// Edge length of the QR code, without the white margin around it.
  static const double qrSize = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.uploadJoinQrTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: qrSize,
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: qrSize,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.uploadJoinQrBody, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            onCopy();
          },
          icon: const Icon(AppIcons.contentPaste, size: 18),
          label: Text(l10n.uploadJoinQrCopy),
        ),
      ],
    );
  }
}
