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
// geoModelProvider (loaded from ONNX + labels assets)
//   └─ exploreSpeciesProvider (combines geo + taxonomy)
// ```
//
// The geoModelProvider is also usable from live mode for species filtering.
// =============================================================================

import 'dart:convert';
import 'dart:io';

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
  final modelVersion = geoConfig['modelVersion'] as int? ?? 0;
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
  });

  final String scientificName;
  final String commonName;
  final double geoScore;
  final TaxonomySpecies? taxonomy;
}

/// Species expected at the user's current location and time, ranked by
/// geo-model probability and enriched with taxonomy metadata.
///
/// Invalidate [currentLocationProvider] to refresh after a location change.
final exploreSpeciesProvider =
    FutureProvider<List<ExploreSpecies>>((ref) async {
  // Wait for all dependencies.
  final location = await ref.watch(currentLocationProvider.future);
  final geoModel = await ref.watch(geoModelProvider.future);
  final taxonomyService = await ref.watch(taxonomyServiceProvider.future);
  final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);

  if (location == null) return const [];

  final week = GeoModel.dateTimeToWeek(DateTime.now());

  final geoResults = geoModel.expectedSpecies(
    latitude: location.latitude,
    longitude: location.longitude,
    week: week,
  );

  return geoResults.map((geo) {
    final taxonomy = taxonomyService.lookup(geo.scientificName);
    return ExploreSpecies(
      scientificName: geo.scientificName,
      commonName:
          taxonomy?.commonNameForLocale(speciesLocale) ?? geo.commonName,
      geoScore: geo.score,
      taxonomy: taxonomy,
    );
  }).toList();
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
