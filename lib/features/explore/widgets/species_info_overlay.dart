// =============================================================================
// Species Info Overlay — Detailed species information bottom sheet
// =============================================================================
//
// A modal bottom sheet showing detailed species information:
//   • Medium image (480×320 WebP, 4:3)
//   • Common name + scientific name
//   • Wikipedia excerpt (if available from API)
//   • External links (eBird, iNaturalist)
//   • Image credit
//
// ### Usage
//
// ```dart
// SpeciesInfoOverlay.show(context, ref, scientificName: 'Parus major');
// ```
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/taxonomy_species.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../explore_providers.dart';

/// Shows a modal bottom sheet with detailed species information.
class SpeciesInfoOverlay {
  SpeciesInfoOverlay._();

  /// Show the species info overlay for the given [scientificName].
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required String scientificName,
    required String commonName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SpeciesInfoSheet(
        scientificName: scientificName,
        commonName: commonName,
      ),
    );
  }
}

class _SpeciesInfoSheet extends ConsumerStatefulWidget {
  const _SpeciesInfoSheet({
    required this.scientificName,
    required this.commonName,
  });

  final String scientificName;
  final String commonName;

  @override
  ConsumerState<_SpeciesInfoSheet> createState() => _SpeciesInfoSheetState();
}

class _SpeciesInfoSheetState extends ConsumerState<_SpeciesInfoSheet> {
  TaxonomySpecies? _detail;
  bool _loading = true;
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final locale = ref.read(effectiveSpeciesLocaleProvider);
      final taxonomyService = await ref.read(taxonomyServiceProvider.future);

      // Try API with locale for descriptions, fall back to local CSV.
      final detail = await taxonomyService.fetchDetail(
        widget.scientificName,
        locale: locale,
      );

      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SpeciesInfoOverlay] fetchDetail error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Image ────────────────────────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: TaxonomyService.mediumUrl(widget.scientificName),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withAlpha(60),
                    ),
                  ),
                ),
              ),

              // ── Names ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _detail?.commonNameForLocale(
                          ref.watch(effectiveSpeciesLocaleProvider)) ??
                      widget.commonName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.scientificName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ),

              // ── Loading indicator ────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // ── Description / Wikipedia excerpt ──────────────
              if (!_loading && _detail != null) ...[
                if (_detail!.descriptionForLocale(
                        ref.watch(effectiveSpeciesLocaleProvider)) !=
                    null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _detail!.descriptionForLocale(
                          ref.watch(effectiveSpeciesLocaleProvider))!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),

                // ── External links ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_detail!.ebirdUrl != null)
                        _LinkChip(
                          label: 'eBird',
                          icon: Icons.public,
                          url: _detail!.ebirdUrl!,
                        ),
                      if (_detail!.inatUrl != null)
                        _LinkChip(
                          label: 'iNaturalist',
                          icon: Icons.nature_people,
                          url: _detail!.inatUrl!,
                        ),
                      if (_detail!.wikipediaUrls != null &&
                          _detail!.wikipediaUrls!.isNotEmpty)
                        _LinkChip(
                          label: 'Wikipedia',
                          icon: Icons.menu_book,
                          url: _detail!.wikipediaUrls!.values.first,
                        ),
                    ],
                  ),
                ),

                // ── Image credit ─────────────────────────────────
                if (_detail!.imageAuthor != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Photo: ${_detail!.imageAuthor}'
                      '${_detail!.imageLicense != null ? ' (${_detail!.imageLicense})' : ''}'
                      '${_detail!.imageSource != null ? ' — ${_detail!.imageSource}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(100),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Link chip widget
// ---------------------------------------------------------------------------

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: theme.textTheme.bodySmall,
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
