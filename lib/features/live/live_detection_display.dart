import 'live_session.dart';
import '../../shared/providers/settings_providers.dart';

/// Builds the species list shown by Live Mode from current-cycle and
/// session-wide detections.
List<DetectionRecord> buildLiveDetectionDisplayList({
  required List<DetectionRecord> currentDetections,
  required List<DetectionRecord> sessionDetections,
  required bool showAllDetectedSpecies,
  required String sortMode,
  String Function(DetectionRecord detection)? localizedCommonName,
}) {
  if (!showAllDetectedSpecies) {
    return List<DetectionRecord>.unmodifiable(currentDetections);
  }

  final currentBySpecies = <String, DetectionRecord>{
    for (final detection in currentDetections)
      detection.scientificName: detection,
  };
  final sessionBySpecies = <String, DetectionRecord>{};
  for (final detection in sessionDetections) {
    sessionBySpecies.putIfAbsent(detection.scientificName, () => detection);
  }

  final result = <DetectionRecord>[
    for (final detection in sessionBySpecies.values)
      currentBySpecies[detection.scientificName] ?? detection,
    for (final detection in currentDetections)
      if (!sessionBySpecies.containsKey(detection.scientificName)) detection,
  ];
  _sortDetectionDisplayList(
    result,
    currentBySpecies: currentBySpecies,
    latestTimestampBySpecies: _latestTimestampBySpecies([
      ...sessionDetections,
      ...currentDetections,
    ]),
    detectionCounts: buildSpeciesDetectionCounts(sessionDetections),
    maxConfidenceBySpecies: _maxConfidenceBySpecies([
      ...sessionDetections,
      ...currentDetections,
    ]),
    localizedName: localizedCommonName ?? ((detection) => detection.commonName),
    sortMode: DetectedSpeciesSortMode.normalize(sortMode),
  );
  return List<DetectionRecord>.unmodifiable(result);
}

/// Counts cumulative detection events by species for the current session.
Map<String, int> buildSpeciesDetectionCounts(
  List<DetectionRecord> sessionDetections,
) {
  final counts = <String, int>{};
  for (final detection in sessionDetections) {
    counts.update(
      detection.scientificName,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return Map<String, int>.unmodifiable(counts);
}

Map<String, DateTime> _latestTimestampBySpecies(
  List<DetectionRecord> detections,
) {
  final timestamps = <String, DateTime>{};
  for (final detection in detections) {
    final existing = timestamps[detection.scientificName];
    if (existing == null || detection.timestamp.isAfter(existing)) {
      timestamps[detection.scientificName] = detection.timestamp;
    }
  }
  return timestamps;
}

/// Highest confidence ever observed per species across the given detections.
///
/// Session detection records hold the per-window peak, so taking the maximum
/// across every record yields the strongest score the species achieved during
/// the session — used to keep confidence sorting stable even after a species
/// stops actively vocalizing.
Map<String, double> _maxConfidenceBySpecies(List<DetectionRecord> detections) {
  final maxima = <String, double>{};
  for (final detection in detections) {
    final existing = maxima[detection.scientificName];
    if (existing == null || detection.confidence > existing) {
      maxima[detection.scientificName] = detection.confidence;
    }
  }
  return maxima;
}

void _sortDetectionDisplayList(
  List<DetectionRecord> detections, {
  required Map<String, DetectionRecord> currentBySpecies,
  required Map<String, DateTime> latestTimestampBySpecies,
  required Map<String, int> detectionCounts,
  required Map<String, double> maxConfidenceBySpecies,
  required String Function(DetectionRecord detection) localizedName,
  required String sortMode,
}) {
  int newestFirst(DetectionRecord a, DetectionRecord b) {
    final aActive = currentBySpecies.containsKey(a.scientificName);
    final bActive = currentBySpecies.containsKey(b.scientificName);
    if (aActive != bActive) return aActive ? -1 : 1;
    if (aActive && bActive) {
      // Currently vocalizing this cycle: strongest current confidence first,
      // so the most prominent live detections stay at the top of the list.
      // For active species the record here is the current-cycle record, so
      // [confidence] is the score just shown to the user.
      final confidence = b.confidence.compareTo(a.confidence);
      if (confidence != 0) return confidence;
      return a.scientificName.compareTo(b.scientificName);
    }
    // Retained (no longer vocalizing): most recent detection first.
    final time = (latestTimestampBySpecies[b.scientificName] ?? b.timestamp)
        .compareTo(latestTimestampBySpecies[a.scientificName] ?? a.timestamp);
    if (time != 0) return time;
    return a.scientificName.compareTo(b.scientificName);
  }

  switch (sortMode) {
    case DetectedSpeciesSortMode.confidence:
      detections.sort((a, b) {
        final aMax = maxConfidenceBySpecies[a.scientificName] ?? a.confidence;
        final bMax = maxConfidenceBySpecies[b.scientificName] ?? b.confidence;
        final confidence = bMax.compareTo(aMax);
        if (confidence != 0) return confidence;
        return newestFirst(a, b);
      });
      return;
    case DetectedSpeciesSortMode.alphabetical:
      detections.sort((a, b) {
        final commonName = localizedName(a)
            .toLowerCase()
            .compareTo(localizedName(b).toLowerCase());
        if (commonName != 0) return commonName;
        return a.scientificName.compareTo(b.scientificName);
      });
      return;
    case DetectedSpeciesSortMode.occurrences:
      detections.sort((a, b) {
        final count = (detectionCounts[b.scientificName] ?? 0).compareTo(
          detectionCounts[a.scientificName] ?? 0,
        );
        if (count != 0) return count;
        return newestFirst(a, b);
      });
      return;
    case DetectedSpeciesSortMode.newest:
    default:
      detections.sort(newestFirst);
      return;
  }
}
