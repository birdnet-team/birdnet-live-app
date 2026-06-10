// =============================================================================
// HTML Session Report
// =============================================================================
//
// Builds a self-contained `report.html` document that ships at the root of
// the export ZIP next to the audio clips. Open it in any browser after the
// archive is unzipped — the page is fully styled, prints cleanly, and lays
// out everything a reviewer needs at a glance:
//
//   • Header card with session metadata (date, duration, location, mode,
//     observer / transect, distance, settings used).
//   • Track + marker map (Leaflet from a public CDN — online only, falls
//     back to a tidy "map needs internet" placeholder otherwise).
//   • Per-detection cards: thumbnail from the BirdNET taxonomy API,
//     localized common name + scientific name, confidence badge,
//     timestamp, optional reviewer note, and an inline `<audio>` player
//     pointing at the clip file already bundled in the same ZIP.
//   • Footer with the BirdNET Live attribution.
//
// Pragmatic by design:
//
//   • No spectrogram rendering (those would balloon the report and we
//     already emit clip audio for playback).
//   • Species images and live taxonomy data come straight from
//     `https://birdnet.cornell.edu/taxonomy/api/image/...` — keeps the
//     HTML small (a few tens of KB) but means images need internet.
//     Placeholder `<svg>` tiles fill in when offline.
//   • Leaflet via `unpkg.com` CDN — no vendoring, ~150 KB saved per
//     report. The map degrades gracefully when offline.
//
// The function returns the full HTML as a String. Bundling into the
// export ZIP happens in `session_export.dart`.
// =============================================================================

import 'dart:convert';

import 'package:intl/intl.dart';

import '../../shared/services/taxonomy_service.dart';
import '../live/live_session.dart';

/// Builds a self-contained HTML report for [session].
///
/// [clipFileMap] maps detection index → clip filename inside the export
/// ZIP (same map produced by `buildSessionExport` for the CSV / Raven
/// outputs). When `null`, audio players are omitted.
///
/// [audioFileName] is the relative filename of the full recording when
/// the session was exported as a single file rather than per-detection
/// clips. When set and [clipFileMap] is null, the report renders one
/// player at the top and uses time-anchored cards (no per-detection
/// `<audio>` tags).
String buildHtmlReport(
  LiveSession session, {
  Map<int, String>? clipFileMap,
  String? audioFileName,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  final dt = DateFormat(
    'EEEE, MMMM d, yyyy · HH:mm',
  ).format(session.startTime.toLocal());
  final title = _esc(session.displayName);
  final modeLabel = _modeLabel(session.type);
  final durationText = _fmtDuration(session.duration);
  final detections = session.detections;
  final hasGps = session.gpsTrack.isNotEmpty;
  final hasMarkers = detections.any(
    (d) => d.latitude != null && d.longitude != null,
  );
  final hasMap = hasGps || hasMarkers;

  // Build the JS data payload as inlined JSON. Keep the field set small
  // and self-explanatory so a third party can repurpose the same blob.
  final dataJson = _buildDataPayload(
    session,
    clipFileMap: clipFileMap,
    taxonomy: taxonomy,
    speciesLocale: speciesLocale,
  );

  final detectionsHtml = _buildDetectionsHtml(
    session,
    clipFileMap: clipFileMap,
    taxonomy: taxonomy,
    speciesLocale: speciesLocale,
  );

  final metadataRows = _buildMetadataRows(session);
  final settingsRows = _buildSettingsRows(session);

  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title — BirdNET Live Report</title>
${hasMap ? '<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">' : ''}
<style>
:root {
  --bg: #f7f7f9;
  --surface: #ffffff;
  --surface-2: #f1f3f6;
  --text: #1f2328;
  --text-muted: #5d6470;
  --border: #e2e5ea;
  --primary: #0d6efd;
  --primary-dim: #0d6efd22;
  --accent: #ff8a3d;
  --score-high: #2ea043;
  --score-mid: #d29922;
  --score-low: #cf222e;
  --shadow: 0 1px 2px rgba(0,0,0,.04), 0 4px 12px rgba(0,0,0,.06);
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14171c;
    --surface: #1c2026;
    --surface-2: #232831;
    --text: #e6e8eb;
    --text-muted: #9aa0a8;
    --border: #2a2f38;
    --primary: #4f9bff;
    --primary-dim: #4f9bff22;
    --shadow: 0 1px 2px rgba(0,0,0,.3), 0 4px 12px rgba(0,0,0,.35);
  }
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 15px;
  line-height: 1.45;
  color: var(--text);
  background: var(--bg);
  padding: 24px 16px 64px;
}
.container { max-width: 960px; margin: 0 auto; }
header.report {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px 24px;
  margin-bottom: 20px;
  box-shadow: var(--shadow);
}
header.report h1 {
  margin: 0 0 4px;
  font-size: 22px;
  font-weight: 600;
  letter-spacing: -0.01em;
}
header.report .subtitle {
  color: var(--text-muted);
  font-size: 14px;
  margin-bottom: 16px;
}
.meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px 24px;
}
.meta-item .label {
  display: block;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--text-muted);
  margin-bottom: 2px;
}
.meta-item .value {
  font-size: 14px;
  font-weight: 500;
}
section.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 16px 20px;
  margin-bottom: 20px;
  box-shadow: var(--shadow);
}
section.card h2 {
  margin: 0 0 12px;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: -0.005em;
}
#map {
  height: 360px;
  border-radius: 8px;
  background: var(--surface-2);
  overflow: hidden;
}
.map-fallback {
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  font-size: 14px;
  background: var(--surface-2);
  border-radius: 8px;
  border: 1px dashed var(--border);
}
.detection-list {
  display: grid;
  grid-template-columns: 1fr;
  gap: 12px;
}
.detection {
  display: grid;
  grid-template-columns: 144px 1fr;
  gap: 14px;
  padding: 12px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  box-shadow: var(--shadow);
}
.detection .thumb {
  width: 144px;
  height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--surface-2);
  position: relative;
}
.detection .thumb img {
  width: 100%; height: 100%;
  object-fit: cover;
  display: block;
}
.detection .thumb .placeholder {
  width: 100%; height: 100%;
  display: flex; align-items: center; justify-content: center;
  color: var(--text-muted);
  font-size: 11px;
  text-align: center;
  padding: 6px;
}
.detection .body { min-width: 0; }
.detection .title-row {
  display: flex;
  align-items: baseline;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 2px;
}
.detection .common {
  font-size: 16px;
  font-weight: 600;
  color: var(--text);
}
.detection .sci {
  font-size: 13px;
  color: var(--text-muted);
  font-style: italic;
}
.detection .meta-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  font-size: 12px;
  color: var(--text-muted);
  margin-bottom: 6px;
}
.score {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 999px;
  font-weight: 600;
  font-size: 12px;
  color: white;
  background: var(--score-mid);
}
.score.high { background: var(--score-high); }
.score.low  { background: var(--score-low); }
.confirmed-pill {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  background: var(--primary-dim);
  color: var(--primary);
}
.detection .note {
  margin: 6px 0 8px;
  padding: 6px 10px;
  background: var(--surface-2);
  border-left: 3px solid var(--primary);
  border-radius: 0 6px 6px 0;
  font-size: 13px;
  white-space: pre-wrap;
}
.detection audio {
  width: 100%;
  height: 32px;
  margin-top: 6px;
}
.detection .stats {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  font-size: 12px;
  color: var(--text-muted);
  margin-bottom: 8px;
}
.detection .count-pill {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  background: var(--surface-2);
  color: var(--text);
}
.occurrences {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-top: 4px;
  padding-top: 8px;
  border-top: 1px dashed var(--border);
}
.occurrence {
  display: grid;
  grid-template-columns: 64px 50px 1fr;
  gap: 8px;
  align-items: center;
  font-size: 12px;
  color: var(--text-muted);
}
.occurrence .occ-time { font-variant-numeric: tabular-nums; }
.occurrence audio {
  width: 100%;
  height: 28px;
}
.occurrence .occ-note {
  grid-column: 1 / -1;
  margin: 2px 0 0;
  padding: 4px 8px;
  background: var(--surface-2);
  border-left: 3px solid var(--primary);
  border-radius: 0 4px 4px 0;
  font-size: 12px;
  color: var(--text);
  white-space: pre-wrap;
}
.occurrence .occ-confirmed {
  display: inline-block;
  padding: 0 6px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 600;
  background: var(--primary-dim);
  color: var(--primary);
  margin-left: 4px;
}
.detection .links {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 4px;
}
.detection .links a {
  color: var(--primary);
  text-decoration: none;
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--primary-dim);
  font-weight: 500;
}
.detection .links a:hover { text-decoration: underline; }
.empty {
  color: var(--text-muted);
  font-style: italic;
  text-align: center;
  padding: 24px;
}
footer {
  text-align: center;
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 32px;
}
footer a { color: var(--primary); text-decoration: none; }
@media print {
  body { background: white; padding: 12px; }
  section.card, header.report, .detection { box-shadow: none; }
  #map, .map-fallback { display: none; }
  audio { display: none; }
}
@media (max-width: 480px) {
  .detection { grid-template-columns: 108px 1fr; }
  .detection .thumb { width: 108px; height: 72px; }
}
.species-pin {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 1px 4px rgba(0,0,0,0.4);
  background-size: cover;
  background-position: center;
  background-color: var(--surface-2);
}
.species-pin.fallback {
  background: #ff8a3d;
}
.popup-card {
  display: flex;
  gap: 8px;
  align-items: center;
  min-width: 180px;
}
.popup-card img {
  width: 60px;
  height: 40px;
  object-fit: cover;
  border-radius: 4px;
  background: #ddd;
}
.popup-card .pop-body { flex: 1; min-width: 0; }
.popup-card .pop-body b { display: block; }
.popup-card .pop-body i { color: #666; font-size: 12px; }
</style>
</head>
<body>
<div class="container">

<header class="report">
  <h1>$title</h1>
  <div class="subtitle">$modeLabel · $dt · ${_esc(durationText)}</div>
  <div class="meta-grid">
    $metadataRows
  </div>
</header>

${hasMap ? '''<section class="card">
  <h2>Map</h2>
  <div id="map"></div>
  <noscript><div class="map-fallback">Enable JavaScript to view the interactive map.</div></noscript>
</section>''' : ''}

${audioFileName != null ? '''<section class="card">
  <h2>Full recording</h2>
  <audio controls preload="none" src="${_esc(Uri.encodeComponent(audioFileName))}"></audio>
</section>''' : ''}

<section class="card">
  <h2>Detections (${detections.length})</h2>
  ${detections.isEmpty ? '<div class="empty">No detections recorded.</div>' : '<div class="detection-list">$detectionsHtml</div>'}
</section>

${settingsRows.isEmpty ? '' : '''<section class="card">
  <h2>Recording settings</h2>
  <div class="meta-grid">
    $settingsRows
  </div>
</section>'''}

<footer>
  Generated by <a href="https://birdnet.cornell.edu" target="_blank" rel="noopener">BirdNET Live</a>.
  Species images &amp; data © <a href="https://birdnet.cornell.edu" target="_blank" rel="noopener">Cornell Lab of Ornithology</a>.
  ${hasMap ? 'Map © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors.' : ''}
</footer>

</div>

<script>
window.SESSION_DATA = $dataJson;
</script>
${hasMap ? '''<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" defer></script>
<script defer>
window.addEventListener('load', function () {
  if (typeof L === 'undefined') {
    var el = document.getElementById('map');
    if (el) el.outerHTML = '<div class="map-fallback">Map needs an internet connection to load tiles.</div>';
    return;
  }
  var data = window.SESSION_DATA;
  var map = L.map('map', { zoomControl: true });
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap contributors'
  }).addTo(map);

  var bounds = L.latLngBounds([]);
  if (data.track && data.track.length) {
    var poly = L.polyline(data.track.map(function (p) { return [p[0], p[1]]; }),
      { color: '#0d6efd', weight: 4, opacity: 0.8 }).addTo(map);
    bounds.extend(poly.getBounds());
  }
  if (data.detections) {
    data.detections.forEach(function (d) {
      if (d.lat == null || d.lon == null) return;
      var icon = L.divIcon({
        className: '',
        html: d.img
          ? '<div class="species-pin" style="background-image:url(\\'' + d.img + '\\')"></div>'
          : '<div class="species-pin fallback"></div>',
        iconSize: [36, 36],
        iconAnchor: [18, 18],
        popupAnchor: [0, -18]
      });
      var m = L.marker([d.lat, d.lon], { icon: icon }).addTo(map);
      var popup = '<div class="popup-card">'
        + (d.img ? '<img src="' + d.img + '" alt="">' : '')
        + '<div class="pop-body"><b>' + escapeHtml(d.common) + '</b>'
        + '<i>' + escapeHtml(d.sci) + '</i>'
        + Math.round(d.conf * 100) + '%</div></div>';
      m.bindPopup(popup);
      bounds.extend(m.getLatLng());
    });
  }
  if (bounds.isValid()) {
    map.fitBounds(bounds, { padding: [24, 24] });
  } else if (data.center) {
    map.setView([data.center[0], data.center[1]], 13);
  } else {
    map.setView([0, 0], 2);
  }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c];
    });
  }
});
</script>''' : ''}
</body>
</html>
''';
}

String _buildDataPayload(
  LiveSession session, {
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  final detections = <Map<String, dynamic>>[];
  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final encodedSci = Uri.encodeComponent(d.scientificName);
    final clipName = clipFileMap?[i];
    detections.add({
      'common': _localizedCommon(d, taxonomy, speciesLocale),
      'sci': d.scientificName,
      'conf': d.confidence,
      'lat': d.latitude,
      'lon': d.longitude,
      // Encode the clip filename so '#' / spaces in user folder paths
      // don't get parsed as URL fragments by the browser.
      'clip': clipName != null ? Uri.encodeComponent(clipName) : null,
      'img':
          'https://birdnet.cornell.edu/taxonomy/api/image/$encodedSci?size=thumb',
    });
  }
  final track = session.gpsTrack.map((p) => [p.latitude, p.longitude]).toList();
  final center = _sessionCenter(session);
  return jsonEncode({
    'detections': detections,
    'track': track,
    if (center != null) 'center': [center.$1, center.$2],
  });
}

String _buildDetectionsHtml(
  LiveSession session, {
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  if (session.detections.isEmpty) return '';
  final timeFmt = DateFormat('HH:mm:ss');
  final start = session.startTime;

  // Group detections by scientific name, mirroring the in-app session
  // review screen (one card per species, individual hits listed inside).
  final indices = <String, List<int>>{};
  for (var i = 0; i < session.detections.length; i++) {
    final sci = session.detections[i].scientificName;
    indices.putIfAbsent(sci, () => []).add(i);
  }
  // Sort species by first-detection time (matches session_review_screen).
  final orderedSpecies =
      indices.keys.toList()..sort((a, b) {
        final ta = session.detections[indices[a]!.first].timestamp;
        final tb = session.detections[indices[b]!.first].timestamp;
        return ta.compareTo(tb);
      });

  final buf = StringBuffer();
  for (final sci in orderedSpecies) {
    final ids = indices[sci]!;
    final firstDet = session.detections[ids.first];
    final common = _localizedCommon(firstDet, taxonomy, speciesLocale);
    // Best confidence across all hits for the species header pill.
    var bestConf = 0.0;
    for (final i in ids) {
      final c = session.detections[i].confidence;
      if (c > bestConf) bestConf = c;
    }
    final bestPct = (bestConf * 100).round();
    final bestClass = bestConf >= 0.7 ? 'high' : (bestConf < 0.4 ? 'low' : '');

    final encodedSci = Uri.encodeComponent(sci);
    final imgUrl =
        'https://birdnet.cornell.edu/taxonomy/api/image/$encodedSci?size=thumb';

    final taxon = taxonomy?.lookup(sci);
    final ebirdUrl = taxon?.ebirdUrl;
    final inatUrl = taxon?.inatUrl;
    String? wikiUrl;
    final wikiMap = taxon?.wikipediaUrls;
    if (wikiMap != null && wikiMap.isNotEmpty) {
      wikiUrl = wikiMap[speciesLocale] ?? wikiMap['en'] ?? wikiMap.values.first;
    }

    buf.writeln('<div class="detection">');
    buf.writeln('  <div class="thumb">');
    buf.writeln(
      '    <img src="${_esc(imgUrl)}" alt="${_esc(common)}" '
      'onerror="this.outerHTML=\'<div class=&quot;placeholder&quot;>No image</div>\'">',
    );
    buf.writeln('  </div>');
    buf.writeln('  <div class="body">');
    buf.writeln('    <div class="title-row">');
    buf.writeln('      <span class="common">${_esc(common)}</span>');
    buf.writeln('      <span class="sci">${_esc(sci)}</span>');
    buf.writeln('    </div>');
    buf.writeln('    <div class="stats">');
    buf.writeln('      <span class="score $bestClass">$bestPct%</span>');
    buf.writeln(
      '      <span class="count-pill">${ids.length} '
      '${ids.length == 1 ? 'detection' : 'detections'}</span>',
    );
    buf.writeln('    </div>');
    if (ebirdUrl != null || inatUrl != null || wikiUrl != null) {
      buf.writeln('    <div class="links">');
      if (ebirdUrl != null) {
        buf.writeln(
          '      <a href="${_esc(ebirdUrl)}" target="_blank" rel="noopener">eBird ↗</a>',
        );
      }
      if (inatUrl != null) {
        buf.writeln(
          '      <a href="${_esc(inatUrl)}" target="_blank" rel="noopener">iNaturalist ↗</a>',
        );
      }
      if (wikiUrl != null) {
        buf.writeln(
          '      <a href="${_esc(wikiUrl)}" target="_blank" rel="noopener">Wikipedia ↗</a>',
        );
      }
      buf.writeln('    </div>');
    }
    // Individual occurrences within this species. Each row: relative
    // time, confidence pill, and (if present) audio clip + note.
    buf.writeln('    <div class="occurrences">');
    for (final i in ids) {
      final d = session.detections[i];
      final confPct = (d.confidence * 100).round();
      final scoreClass =
          d.confidence >= 0.7 ? 'high' : (d.confidence < 0.4 ? 'low' : '');
      final relSec = d.timestamp.difference(start).inSeconds;
      final relText = _fmtRelative(relSec);
      final wallText = timeFmt.format(d.timestamp.toLocal());
      // Encode clip filename so '#' or spaces in the user's folder
      // don't get parsed as URL fragments by the browser.
      final clipNameRaw = clipFileMap?[i];
      final clipNameEncoded =
          clipNameRaw != null ? Uri.encodeComponent(clipNameRaw) : null;
      final note = d.note;
      final hasNote = note != null && note.trim().isNotEmpty;

      buf.writeln('      <div class="occurrence">');
      buf.writeln('        <span class="occ-time">${_esc(wallText)}</span>');
      buf.writeln('        <span class="score $scoreClass">$confPct%</span>');
      if (clipNameEncoded != null) {
        buf.writeln(
          '        <audio controls preload="none" src="${_esc(clipNameEncoded)}"></audio>',
        );
      } else {
        buf.writeln(
          '        <span style="color:var(--text-muted)">${_esc(relText)}</span>',
        );
      }
      if (d.isConfirmed) {
        buf.writeln('        <span class="occ-confirmed">Confirmed</span>');
      }
      if (hasNote) {
        buf.writeln('        <div class="occ-note">${_esc(note.trim())}</div>');
      }
      buf.writeln('      </div>');
    }
    buf.writeln('    </div>');
    buf.writeln('  </div>');
    buf.writeln('</div>');
  }
  return buf.toString();
}

String _buildMetadataRows(LiveSession session) {
  final rows = <(String, String)>[];
  if (session.locationName != null && session.locationName!.isNotEmpty) {
    rows.add(('Location', session.locationName!));
  }
  if (session.latitude != null && session.longitude != null) {
    rows.add((
      'Coordinates',
      '${session.latitude!.toStringAsFixed(4)}, '
          '${session.longitude!.toStringAsFixed(4)}',
    ));
  }
  if (session.observerName != null && session.observerName!.isNotEmpty) {
    rows.add(('Observer', session.observerName!));
  }
  if (session.transectId != null && session.transectId!.isNotEmpty) {
    rows.add(('Transect', session.transectId!));
  }
  if (session.distanceMeters != null && session.distanceMeters! > 0) {
    final km = session.distanceMeters! / 1000.0;
    rows.add((
      'Distance',
      km >= 1
          ? '${km.toStringAsFixed(2)} km'
          : '${session.distanceMeters!.round()} m',
    ));
  }
  if (session.weather != null) {
    final w = session.weather!;
    if (w.temperatureC != null) {
      rows.add(('Temperature', '${w.temperatureC!.toStringAsFixed(1)} °C'));
    }
    if (w.windSpeedMs != null) {
      final dir = w.windDirectionDeg;
      final compass = dir == null ? '' : _compass(dir);
      rows.add((
        'Wind',
        compass.isEmpty
            ? '${w.windSpeedMs!.toStringAsFixed(1)} m/s'
            : '${w.windSpeedMs!.toStringAsFixed(1)} m/s $compass',
      ));
    }
    if (w.precipitationMm != null) {
      rows.add((
        'Precipitation',
        '${w.precipitationMm!.toStringAsFixed(1)} mm',
      ));
    }
    if (w.cloudCoverPercent != null) {
      rows.add(('Cloud cover', '${w.cloudCoverPercent} %'));
    }
  }
  rows.add(('Detections', session.detections.length.toString()));
  rows.add((
    'Species',
    session.detections.map((d) => d.scientificName).toSet().length.toString(),
  ));
  return rows
      .map(
        (r) =>
            '<div class="meta-item">'
            '<span class="label">${_esc(r.$1)}</span>'
            '<span class="value">${_esc(r.$2)}</span>'
            '</div>',
      )
      .join('\n    ');
}

String _buildSettingsRows(LiveSession session) {
  final s = session.settings;
  final rows = <(String, String)>[];
  rows.add(('Window', '${s.windowDuration} s'));
  rows.add(('Min confidence', '${s.confidenceThreshold}%'));
  if (s.sensitivity != null) {
    rows.add(('Sensitivity', s.sensitivity!.toStringAsFixed(2)));
  }
  if (s.poolingMode != null && s.poolingWindows != null) {
    rows.add(('Pooling', '${s.poolingMode} (${s.poolingWindows} windows)'));
  }
  if (s.gainLinear != null) {
    rows.add(('Gain', '${s.gainLinear!.toStringAsFixed(2)}×'));
  }
  if (s.highPassHz != null && s.highPassHz! > 0) {
    rows.add(('High-pass', '${s.highPassHz!.round()} Hz'));
  }
  return rows
      .map(
        (r) =>
            '<div class="meta-item">'
            '<span class="label">${_esc(r.$1)}</span>'
            '<span class="value">${_esc(r.$2)}</span>'
            '</div>',
      )
      .join('\n    ');
}

(double, double)? _sessionCenter(LiveSession session) {
  if (session.latitude != null && session.longitude != null) {
    return (session.latitude!, session.longitude!);
  }
  if (session.gpsTrack.isNotEmpty) {
    final p = session.gpsTrack.first;
    return (p.latitude, p.longitude);
  }
  for (final d in session.detections) {
    if (d.latitude != null && d.longitude != null) {
      return (d.latitude!, d.longitude!);
    }
  }
  return null;
}

String _localizedCommon(
  DetectionRecord d,
  TaxonomyService? taxonomy,
  String speciesLocale,
) {
  if (taxonomy == null) return d.commonName;
  final sp = taxonomy.lookup(d.scientificName);
  if (sp == null) return d.commonName;
  final localized = sp.commonNameForLocale(speciesLocale);
  return localized.isNotEmpty ? localized : d.commonName;
}

String _modeLabel(SessionType type) {
  switch (type) {
    case SessionType.live:
      return 'Live session';
    case SessionType.pointCount:
      return 'Point count';
    case SessionType.survey:
      return 'Survey';
    case SessionType.fileUpload:
      return 'File analysis';
    case SessionType.batchAnalysis:
      return 'Batch analysis';
    case SessionType.aru:
      return 'ARU session';
  }
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String _fmtRelative(int seconds) {
  final neg = seconds < 0;
  final abs = seconds.abs();
  final h = abs ~/ 3600;
  final m = (abs % 3600) ~/ 60;
  final s = abs % 60;
  final body =
      h > 0
          ? '${h}h${m.toString().padLeft(2, '0')}m${s.toString().padLeft(2, '0')}s'
          : '$m:${s.toString().padLeft(2, '0')}';
  return neg ? '−$body' : '+$body';
}

String _esc(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _compass(double bearingDeg) {
  final n = ((bearingDeg % 360) + 360) % 360;
  const sectors = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return sectors[((n + 22.5) / 45).floor() % 8];
}
