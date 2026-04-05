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
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../core/services/location_service.dart';
import '../inference/geo_model.dart';

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
  final configJson =
      await rootBundle.loadString(AppConstants.modelConfigAssetPath);
  final fullConfig = json.decode(configJson) as Map<String, dynamic>;
  final labelsConfig = (fullConfig['audioModel']
      as Map<String, dynamic>)['labels'] as Map<String, dynamic>;

  final file = labelsConfig['file'] as String;
  final delimiter = labelsConfig['delimiter'] as String? ?? ';';
  final cols = labelsConfig['columns'] as Map<String, dynamic>? ?? const {};
  final sciNameColHeader = cols['scientificName'] as String? ?? 'sci_name';

  final csvText =
      await rootBundle.loadString('${AppConstants.modelAssetsDir}/$file');
  final lines = csvText
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
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Current device location — refreshed on demand via [ref.invalidate].
///
/// Falls back to manual coordinates when GPS is disabled.
final currentLocationProvider = FutureProvider<AppLocation?>((ref) async {
  final useGps = ref.watch(useGpsProvider);
  final service = ref.watch(locationServiceProvider);

  if (!useGps) {
    final lat = ref.watch(manualLatitudeProvider);
    final lon = ref.watch(manualLongitudeProvider);
    return AppLocation(latitude: lat, longitude: lon);
  }

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

  // Ensure ONNX file is on disk (same pattern as the audio model).
  // Use modelVersion from config to detect when asset has been updated.
  final modelVersion = geoConfig['version'] as String? ?? '0';
  final appDir = await getApplicationDocumentsDirectory();
  final versionedName = '${modelFile}_v$modelVersion';
  final onnxFile = File('${appDir.path}/$versionedName');

  if (!onnxFile.existsSync()) {
    debugPrint('[geoModelProvider] extracting geo model v$modelVersion '
        'to ${onnxFile.path}');
    final data = await rootBundle.load(
      '${AppConstants.modelAssetsDir}/$modelFile',
    );
    await onnxFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  final geoModel = GeoModel();
  geoModel.loadLabels(labelsText);
  await geoModel.loadModel(onnxFile.path);

  debugPrint('[geoModelProvider] geo model ready '
      '(${geoModel.labels.length} species)');
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
    this.taxonomy,
    this.weeklyScores,
  });

  final String scientificName;
  final String commonName;
  final double geoScore;
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
final exploreSpeciesProvider =
    FutureProvider<List<ExploreSpecies>>((ref) async {
  // Wait for all dependencies.
  final location = await ref.watch(currentLocationProvider.future);
  final geoModel = await ref.watch(geoModelProvider.future);
  final taxonomyService = await ref.watch(taxonomyServiceProvider.future);
  final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
  final audioLabels = await ref.watch(audioLabelsSetProvider.future);

  if (location == null) return const [];

  final currentWeek = GeoModel.dateTimeToWeek(DateTime.now());

  // Run all 48 weeks directly (no isolate — small model, fast inference).
  final allWeeks = geoModel.predictAllWeeks(
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
    final geoLabel = geoModel.labels.where(
      (l) => l.scientificName == sciName,
    );
    final commonName = taxonomy?.commonNameForLocale(speciesLocale) ??
        (geoLabel.isNotEmpty ? geoLabel.first.commonName : sciName);

    results.add(ExploreSpecies(
      scientificName: sciName,
      commonName: commonName,
      geoScore: currentScore,
      taxonomy: taxonomy,
      weeklyScores: weeklyScores,
    ));
  }

  // Sort by current-week probability (descending).
  results.sort((a, b) => b.geoScore.compareTo(a.geoScore));

  // Normalize scores against the top species (max score = 100.0).
  if (results.isNotEmpty) {
    final maxScore = results.first.geoScore;
    if (maxScore > 0) {
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        results[i] = ExploreSpecies(
          scientificName: r.scientificName,
          commonName: r.commonName,
          geoScore: (r.geoScore / maxScore) * 100.0,
          taxonomy: r.taxonomy,
          weeklyScores:
              r.weeklyScores?.map((s) => (s / maxScore) * 100.0).toList(),
        );
      }
    }
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
  return geoModel.geoScoresForFilter(
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

/// Returns a color for the probability category.
Color probabilityCategoryColor(double score) {
  if (score >= 80) return const Color(0xFF2E7D32); // forest green
  if (score >= 60) return const Color(0xFFAFB42B); // yellow-green
  if (score >= 40) return const Color(0xFFFBC02D); // yellow/amber
  if (score >= 20) return const Color(0xFFF57C00); // orange
  return const Color(0xFFD32F2F); // red
}
