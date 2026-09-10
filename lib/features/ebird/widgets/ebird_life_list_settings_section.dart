// =============================================================================
// eBird Life List Settings Section
// =============================================================================
//
// Lets the user import their eBird life list CSV export so the app can flag
// species it hears that aren't on that list yet (a "lifer") — on the Live
// screen, in session review summaries, and via Survey Mode's alert system.
// =============================================================================

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/link_launcher.dart';
import '../../../shared/utils/app_icons.dart';
import '../ebird_life_list.dart';

const _ebirdLifeListCsvUrl =
    'https://ebird.org/lifelist?r=world&time=life&fmt=csv';

class EbirdLifeListSettingsSection extends ConsumerStatefulWidget {
  const EbirdLifeListSettingsSection({super.key});

  @override
  ConsumerState<EbirdLifeListSettingsSection> createState() =>
      _EbirdLifeListSettingsSectionState();
}

class _EbirdLifeListSettingsSectionState
    extends ConsumerState<EbirdLifeListSettingsSection> {
  bool _busy = false;
  String? _error;

  Future<void> _importCsv() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        return;
      }
      final bytes = await result.files.single.xFile.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final lifeList = ref.read(ebirdLifeListProvider);
      await lifeList.importCsv(content);
      if (!mounted) return;
      setState(() => _busy = false);
    } on EbirdCsvFormatException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.ebirdLifeListImportError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lifeList = ref.watch(ebirdLifeListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ebirdLifeListTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.ebirdLifeListDescription, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _importCsv,
                child: Text(l10n.ebirdLifeListImportButton),
              ),
              const SizedBox(width: 12),
              if (!lifeList.isEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ebirdLifeListSpeciesCount(lifeList.length),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (lifeList.importedAt != null)
                        Text(
                          l10n.ebirdLifeListImportedOn(
                            DateFormat.yMMMd().format(lifeList.importedAt!),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap:
                  () => openExternalUrl(
                    context,
                    _ebirdLifeListCsvUrl,
                    inApp: true,
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.ebirdLifeListGetListLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    AppIcons.openInNew,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
