// =============================================================================
// Text Prompt Dialog — one text field, Cancel, Save
// =============================================================================
//
// The dialog owns its TextEditingController. A caller-owned controller that
// is disposed right after showDialog returns is still read by the field
// during the dialog's exit animation, which throws "A TextEditingController
// was used after being disposed" on every frame of that animation.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

/// Shows [TextPromptDialog] and returns the entered text, or null when
/// cancelled. The text is not trimmed.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  String initialText = '',
  String? labelText,
  String? helperText,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: title,
      initialText: initialText,
      labelText: labelText,
      helperText: helperText,
      textCapitalization: textCapitalization,
    ),
  );
}

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    this.initialText = '',
    this.labelText,
    this.helperText,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String title;
  final String initialText;
  final String? labelText;
  final String? helperText;
  final TextCapitalization textCapitalization;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          labelText: widget.labelText,
          helperText: widget.helperText,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
