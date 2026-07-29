// =============================================================================
// Explore Providers — Riverpod wiring for the Explore feature
// =============================================================================
//
// Connects the [GeoModel], [LocationService], and [TaxonomyService] to the
// widget tree and other features.
//
// ### Provider dependency graph
//
// ```
// locationServiceProvider
//   └─ currentLocationProvider
//
// taxonomyServiceProvider (loaded from CSV asset)
//
// audioLabelsSetProvider (scientific names the audio model can detect)
//
// geoModelProvider (loaded from ONNX + labels assets)
//   └─ geoModelSpeciesNamesProvider (set of all geo-model scientific names)
//   └─ exploreSpeciesProvider (combines geo + taxonomy, intersected with audio)
// ```
//
// The geoModelProvider and geoModelSpeciesNamesProvider are also used from
// live mode to restrict detections to species both models know about.
// =============================================================================

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/score_colors.dart';
import '../../core/services/asset_pack_service.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/species_description_service.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../core/services/location_service.dart';
import '../inference/geo_model.dart';
import 'explore_tier.dart';

// ---------------------------------------------------------------------------
// Audio labels intersection set
// ---------------------------------------------------------------------------

/// Scientific names of every species the audio classifier model can detect.
///
/// Parsed from the labels CSV only — no ONNX loaded.  Used to intersect
/// with the geo-model species list so that:
///   - Explore only shows species the audio model can also detect.
///   - Live only shows detections for species the geo-model also knows.
final audioLabelsSetProvider = FutureProvider<Set<String>>((ref) async {
  final configJson = await rootBundle.loadString(
    AppConstants.modelConfigAssetPath,
  );
  final fullConfig = json.decode(configJson) as Map<String, dynamic>;
  final labelsConfig =
      (fullConfig['audioModel'] as Map<String, dynamic>)['labels']
          as Map<String, dynamic>;

  final file = labelsConfig['file'] as String;
  final delimiter = labelsConfig['delimiter'] as String? ?? ';';
  final cols = labelsConfig['columns'] as Map<String, dynamic>? ?? const {};
  final sciNameColHeader = cols['scientificName'] as String? ?? 'sci_name';

  final csvText = await rootBundle.loadString(
    '${AppConstants.modelAssetsDir}/$file',
  );
  final lines =
      csvText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
  if (lines.isEmpty) return {};

  final headers = lines.first.split(delimiter).map((h) => h.trim()).toList();
  final sciIdx = headers.indexOf(sciNameColHeader);
  if (sciIdx < 0) return {};

  return lines
      .skip(1)
      .map((l) {
        final parts = l.split(delimiter);
        return sciIdx < parts.length ? parts[sciIdx].trim() : '';
      })
      .where((s) => s.isNotEmpty)
      .toSet();
});

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

/// Singleton [LocationService] instance.
///
/// The service reads "Use GPS" and the manual coordinates through these
/// callbacks on every call, so the setting is enforced inside the service —
/// every feature that fetches a location honours it, not just the ones that
/// remember to check [useGpsProvider] first.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(
    gpsEnabled: () => ref.read(useGpsProvider),
    manualLocation:
        () => AppLocation(
          latitude: ref.read(manualLatitudeProvider),
          longitude: ref.read(manualLongitudeProvider),
        ),
  );
});

/// Current device location — refreshed on demand via [ref.invalidate].
///
/// Falls back to manual coordinates when GPS is disabled; that is enforced
/// inside [LocationService], and the watches here only decide *when* this
/// provider recomputes.
///
/// Keep the manual-coordinate watches inside the `!useGps` branch. Widening
/// them adds ways for this provider to be dirty, and every extra invalidation
/// is a chance to hit a Riverpod "setState during build": a widget whose first
/// build flushes this provider (the GPS tile in Settings, built lazily by a
/// ListView) makes the `.future` proxy notify mid-build, and the providers
/// that `watch(currentLocationProvider.future)` then invalidate themselves
/// while the frame is still building.
final currentLocationProvider = FutureProvider<AppLocation?>((ref) async {
  final useGps = ref.watch(useGpsProvider);
  if (!useGps) {
    ref
      ..watch(manualLatitudeProvider)
      ..watch(manualLongitudeProvider);
  }
  final service = ref.watch(locationServiceProvider);

  return service.getCurrentLocation();
});

// ---------------------------------------------------------------------------
// Taxonomy
// ---------------------------------------------------------------------------

/// Singleton [TaxonomyService] loaded from the bundled CSV.
final taxonomyServiceProvider = FutureProvider<TaxonomyService>((ref) async {
  final service = TaxonomyService();
  final csvContent = await rootBundle.loadString(
    '${AppConstants.modelAssetsDir}/taxonomy.csv',
  );
  service.loadFromCsv(csvContent);
  return service;
});

/// Singleton [SpeciesDescriptionService] for loading bundled descriptions.
final speciesDescriptionServiceProvider = Provider<SpeciesDescriptionService>((
  ref,
) {
  return SpeciesDescriptionService();
});

// ---------------------------------------------------------------------------
// Geo Model
// ---------------------------------------------------------------------------

/// Loaded [GeoModel] — ready to call [predict].
///
/// Extracts the ONNX model to disk (if needed) and loads both the model
/// and labels from assets.  This is reusable: live mode and explore mode
/// can both watch this provider.
final geoModelProvider = FutureProvider<GeoModel>((ref) async {
  // Load model config to get file names.
  final configJson = await rootBundle.loadString(
    AppConstants.modelConfigAssetPath,
  );
  final config = json.decode(configJson) as Map<String, dynamic>;
  final geoConfig = config['geoModel'] as Map<String, dynamic>;

  final modelFile = geoConfig['modelFile'] as String;
  final labelsFile = geoConfig['labelsFile'] as String;

  // Load labels from asset bundle.
  final labelsText = await rootBundle.loadString(
    '${AppConstants.modelAssetsDir}/$labelsFile',
  );

  // Resolve the geo-model ONNX file via the install-time asset pack
  // (Play Store AAB) or fall back to extracting from rootBundle (sideload
  // APK). Use modelVersion from config to detect when the asset has been
  // updated so a fresh extraction kicks in.
  final modelVersion = geoConfig['version'] as String? ?? '0';
  final onnxPath = await AssetPackService.resolveModelPath(
    fileName: modelFile,
    version: modelVersion,
  );

  final geoModel = GeoModel();
  geoModel.loadLabels(labelsText);
  await geoModel.loadModel(onnxPath);

  debugPrint(
    '[geoModelProvider] geo model ready '
    '(${geoModel.labels.length} species)',
  );
  return geoModel;
});

/// Set of all scientific names in the geo-model's label file.
///
/// Available regardless of location — derived from the already-loaded
/// [GeoModel].  Used by the live controller to restrict detections to
/// species both models know about.
final geoModelSpeciesNamesProvider = FutureProvider<Set<String>>((ref) async {
  final geoModel = await ref.watch(geoModelProvider.future);
  return geoModel.labels.map((l) => l.scientificName).toSet();
});

// ---------------------------------------------------------------------------
// Explore — species list for current location & time
// ---------------------------------------------------------------------------

/// A species with its geo-model probability and taxonomy metadata.
class ExploreSpecies {
  const ExploreSpecies({
    required this.scientificName,
    required this.commonName,
    required this.geoScore,
    required this.rawGeoScore,
    required this.tier,
    this.taxonomy,
    this.weeklyScores,
  });

  final String scientificName;
  final String commonName;

  /// Current-week score normalized so the top species in the list is 100.
  /// Kept for the mini bar chart and legacy displays.
  final double geoScore;

  /// Raw current-week geo-model probability (0-1) before list normalization.
  /// Feeds the distribution-adaptive [tier].
  final double rawGeoScore;

  /// Distribution-adaptive abundance tier for this species within the list.
  final ExploreTier tier;

  final TaxonomySpecies? taxonomy;

  /// 48-week probability curve (index 0 = week 1, etc.). Null until loaded.
  final List<double>? weeklyScores;
}

/// Species expected at the user's current location and time, ranked by
/// geo-model probability for the current week and enriched with taxonomy
/// metadata and 48-week probability curves.
///
/// Only species present in both the geo-model and the audio classifier are
/// included — the audio model must be able to detect what is shown.
///
/// Invalidate [currentLocationProvider] to refresh after a location change.
final exploreSpeciesProvider = FutureProvider<List<ExploreSpecies>>((
  ref,
) async {
  // Wait for all dependencies.
  final location = await ref.watch(currentLocationProvider.future);
  final geoModel = await ref.watch(geoModelProvider.future);
  final taxonomyService = await ref.watch(taxonomyServiceProvider.future);
  final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
  final audioLabels = await ref.watch(audioLabelsSetProvider.future);

  if (location == null) return const [];

  final currentWeek = GeoModel.dateTimeToWeek(DateTime.now());

  // Run all 48 weeks directly (no isolate — small model, fast inference).
  final allWeeks = await geoModel.predictAllWeeks(
    latitude: location.latitude,
    longitude: location.longitude,
  );

  // Build species list filtered by current-week score.
  const threshold = 0.03;
  final results = <ExploreSpecies>[];

  for (final entry in allWeeks.entries) {
    final sciName = entry.key;
    final weeklyScores = entry.value;
    final currentScore = weeklyScores[currentWeek - 1];

    if (currentScore < threshold) continue;

    // Only include species the audio model can also detect.
    if (!audioLabels.contains(sciName)) continue;

    final taxonomy = taxonomyService.lookup(sciName);
    final geoLabel = geoModel.labels.where((l) => l.scientificName == sciName);
    final commonName =
        taxonomy?.commonNameForLocale(speciesLocale) ??
        (geoLabel.isNotEmpty ? geoLabel.first.commonName : sciName);

    results.add(
      ExploreSpecies(
        scientificName: sciName,
        commonName: commonName,
        geoScore: currentScore,
        rawGeoScore: currentScore,
        tier: ExploreTier.rare,
        taxonomy: taxonomy,
        weeklyScores: weeklyScores,
      ),
    );
  }

  // Sort by current-week probability (descending).
  results.sort((a, b) => b.geoScore.compareTo(a.geoScore));

  // Distribution-adaptive abundance tiers, calibrated from the raw scores of
  // this location/week so the tier boundaries reflect how many species are
  // high-scoring here (see [ExploreTierScale]).
  final tierScale = ExploreTierScale.fromScores(
    results.map((r) => r.rawGeoScore),
  );

  // Normalize scores against the top species (max score = 100.0) for the mini
  // bar chart, while preserving the raw score and assigning the adaptive tier.
  final maxScore = results.isNotEmpty ? results.first.geoScore : 0.0;
  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    final normalize = maxScore > 0;
    results[i] = ExploreSpecies(
      scientificName: r.scientificName,
      commonName: r.commonName,
      geoScore: normalize ? (r.geoScore / maxScore) * 100.0 : r.geoScore,
      rawGeoScore: r.rawGeoScore,
      tier: tierScale.tierFor(r.rawGeoScore),
      taxonomy: r.taxonomy,
      weeklyScores:
          normalize
              ? r.weeklyScores?.map((s) => (s / maxScore) * 100.0).toList()
              : r.weeklyScores,
    );
  }

  return results;
});

/// Geo-model scores as a `Map<scientificName, score>` for use by the
/// species filter in live mode.
///
/// Returns null if no location is available or the model isn't loaded yet.
final geoScoresProvider = FutureProvider<Map<String, double>?>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final geoModel = await ref.watch(geoModelProvider.future);

  if (location == null) return null;

  final week = GeoModel.dateTimeToWeek(DateTime.now());
  return await geoModel.geoScoresForFilter(
    latitude: location.latitude,
    longitude: location.longitude,
    week: week,
  );
});

// ---------------------------------------------------------------------------
// Probability category mapping
// ---------------------------------------------------------------------------

/// Maps a normalized geo model score (0–100) to a qualitative frequency label.
String probabilityCategory(double score) {
  if (score >= 80) return 'Abundant';
  if (score >= 60) return 'Common';
  if (score >= 40) return 'Uncommon';
  if (score >= 20) return 'Occasional';
  return 'Rare';
}

/// Returns a color for the probability category by routing through the
/// app-wide [ScoreColors] theme extension. Score is on the 0–100 geo-score
/// scale and gets normalized to 0–1 internally so a single CVD-safe ramp
/// drives every confidence/likelihood badge in the app.
Color probabilityCategoryColor(BuildContext context, double score) {
  final colors = ScoreColors.of(context);
  return colors.forScore((score / 100).clamp(0.0, 1.0));
}
