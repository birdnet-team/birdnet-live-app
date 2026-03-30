// =============================================================================
// Explore Screen — Browse species in your area
// =============================================================================
//
// Shows a scrollable list of bird species that the geo-model predicts as
// likely present at the user's current location and time of year.
//
// Each species is displayed as a [SpeciesCard] with a thumbnail image,
// common name, scientific name, and geo-model probability.  Tapping a
// card opens the [SpeciesInfoOverlay] with detailed information.
//
// The screen uses [exploreSpeciesProvider] which combines GPS location,
// the ONNX geo-model, and the taxonomy CSV for a rich species list.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'explore_providers.dart';
import 'widgets/species_card.dart';
import 'widgets/species_info_overlay.dart';

/// The Explore screen — browse species expected in your area.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final speciesAsync = ref.watch(exploreSpeciesProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exploreTitle),
        actions: [
          // Refresh location + species list.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.exploreRefresh,
            onPressed: () {
              ref.invalidate(currentLocationProvider);
              ref.invalidate(exploreSpeciesProvider);
            },
          ),
        ],
      ),
      body: speciesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(currentLocationProvider);
            ref.invalidate(exploreSpeciesProvider);
          },
        ),
        data: (species) {
          if (species.isEmpty) {
            return _EmptyView(
              locationAvailable: locationAsync.valueOrNull != null,
            );
          }

          return Column(
            children: [
              // ── Location & count header ─────────────────────
              _LocationHeader(ref: ref, speciesCount: species.length),
              const Divider(height: 1),

              // ── Species list ────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: species.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = species[index];
                    return SpeciesCard(
                      scientificName: s.scientificName,
                      commonName: s.commonName,
                      geoScore: s.geoScore,
                      onTap: () => SpeciesInfoOverlay.show(
                        context,
                        ref,
                        scientificName: s.scientificName,
                        commonName: s.commonName,
                      ),
                    );
                  },
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
// Location header — shows coordinates and species count
// ---------------------------------------------------------------------------

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.ref,
    required this.speciesCount,
  });

  final WidgetRef ref;
  final int speciesCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(currentLocationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: locationAsync.when(
              data: (loc) => Text(
                loc != null
                    ? '${loc.latitude.toStringAsFixed(3)}, ${loc.longitude.toStringAsFixed(3)}'
                    : l10n.exploreNoLocation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              loading: () => Text(
                l10n.exploreLocating,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              error: (_, __) => Text(
                l10n.exploreLocationError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
          Text(
            l10n.exploreSpeciesCount(speciesCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.locationAvailable});

  final bool locationAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              locationAvailable ? Icons.search_off : Icons.location_off,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              locationAvailable
                  ? l10n.exploreNoSpecies
                  : l10n.exploreNoLocation,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(170),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
