// =============================================================================
// HTML Session Report
// =============================================================================
//
// Builds a self-contained `<session>_report.html` document that ships at the
// root of the export ZIP next to the audio clips. The session-name prefix
// keeps reports from colliding when several archives are extracted into the
// same folder. Open it in any browser after the
// archive is unzipped - the page is fully styled, prints cleanly, and lays
// out everything a reviewer needs at a glance:
//
//   - Header card: session metadata, quick-stats bar (total detections,
//     species count, max confidence, top species).
//   - Activity timeline: canvas bar-chart of detections per time-bin.
//   - Track + marker map (Leaflet from CDN - online only).
//   - Per-species cards: collapsible, thumbnail, confidence badge, count,
//     eBird / iNaturalist / Wikipedia links.
//     > Each occurrence: timestamp, confidence pill, and inline `<audio>`
//       player when a clip is bundled.
//   - Search & sort toolbar: filter by name, sort by time / count /
//     confidence / A-Z, expand / collapse all.
//   - Settings + extended session-detail sections at the bottom.
//   - Footer with BirdNET Live attribution.
//
// Pragmatic by design:
//   - Species images come from Cornell's taxonomy API - needs internet.
//   - Leaflet from unpkg.com CDN - map degrades gracefully offline.
//
// The function returns the full HTML as a String. Bundling into the
// export ZIP happens in `session_export.dart`.
// =============================================================================

import 'dart:convert';

import 'package:intl/intl.dart';

import '../../shared/services/taxonomy_service.dart';
import '../live/live_session.dart';
import 'services/session_audio_trim.dart';

/// Builds a self-contained HTML report for [session].
///
/// [clipFileMap] maps detection index -> clip filename inside the export
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
  Map<String, dynamic>? metadata,
}) {
  final dt = DateFormat(
    'EEEE, MMMM d, yyyy HH:mm',
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
  final hasDetections = detections.isNotEmpty;

  // Escape hatch for the map card. Leaflet and the OSM tile service are both
  // remote, and a report opened from `file://` can lose either one (Firefox
  // gets 403s from tile.openstreetmap.org where Chromium does not, and a
  // blocked CDN kills Leaflet outright). This link is plain HTML, so it works
  // no matter what the browser refuses to fetch.
  final osmLinkHtml = hasMap ? _buildOsmLinkHtml(_sessionCenter(session)) : '';

  // Quick stats for the header bar.
  final speciesSet = detections.map((d) => d.scientificName).toSet();
  final speciesCount = speciesSet.length;
  var maxConf = 0.0;
  final speciesCounts = <String, int>{};
  for (final d in detections) {
    if (d.confidence > maxConf) maxConf = d.confidence;
    speciesCounts[d.scientificName] =
        (speciesCounts[d.scientificName] ?? 0) + 1;
  }
  String topSpeciesHtml = '';
  if (speciesCounts.isNotEmpty) {
    final topSci =
        speciesCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final topDet = detections.firstWhere((d) => d.scientificName == topSci);
    final topCommon = _localizedCommon(topDet, taxonomy, speciesLocale);
    topSpeciesHtml = '<span>Top: <strong>${_esc(topCommon)}</strong></span>';
  }

  final statsItems = <String>[
    '<span><strong>${detections.length}</strong> detection${detections.length == 1 ? '' : 's'}</span>',
    '<span><strong>$speciesCount</strong> ${speciesCount == 1 ? 'species' : 'species'}</span>',
    if (maxConf > 0)
      '<span>Max <strong>${(maxConf * 100).round()}%</strong> confidence</span>',
    if (topSpeciesHtml.isNotEmpty) topSpeciesHtml,
  ];
  final statsBarHtml = statsItems.join(
    '<span class="stat-sep">&middot;</span>',
  );

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
  final extendedRows = _buildExtendedMetaRows(session);
  final footerContextHtml = _buildFooterContextHtml(session, metadata);

  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title - BirdNET Live Report</title>
<script>document.documentElement.classList.add('player-js');</script>
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
  --shadow-lg: 0 2px 8px rgba(0,0,0,.07), 0 8px 24px rgba(0,0,0,.1);
  --tr: .15s ease;
  --r: 12px;
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
    --shadow-lg: 0 2px 8px rgba(0,0,0,.45), 0 8px 24px rgba(0,0,0,.5);
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

/* -- Header ------------------------------------------------- */
header.report {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 20px 24px;
  margin-bottom: 20px;
  box-shadow: var(--shadow);
}
header.report h1 {
  margin: 0 0 2px;
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -.02em;
}
header.report .subtitle {
  color: var(--text-muted);
  font-size: 14px;
  margin-bottom: 14px;
}
.stats-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  font-size: 13px;
  color: var(--text-muted);
  background: var(--surface-2);
  border-radius: 8px;
  padding: 8px 14px;
  margin-bottom: 16px;
}
.stats-bar strong { color: var(--text); }
.stat-sep { color: var(--border); opacity: .7; }

/* -- Meta grid ---------------------------------------------- */
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
.meta-item .value { font-size: 14px; font-weight: 500; }

/* -- Card shell --------------------------------------------- */
section.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 16px 20px;
  margin-bottom: 20px;
  box-shadow: var(--shadow);
}
section.card h2 {
  margin: 0 0 12px;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: -.005em;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.section-badge {
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  background: var(--surface-2);
  padding: 2px 8px;
  border-radius: 999px;
  letter-spacing: 0;
}

/* -- Map ---------------------------------------------------- */
#map {
  height: 380px;
  border-radius: 8px;
  background: var(--surface-2);
  overflow: hidden;
}
.map-fallback {
  height: 180px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  font-size: 14px;
  background: var(--surface-2);
  border-radius: 8px;
  border: 1px dashed var(--border);
}
.map-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.map-head h2 { margin: 0; }
/* Escape hatch that never depends on tiles loading. */
.map-osm-link { font-size: 13px; white-space: nowrap; }
/* Shown only when tiles actually fail; see initMap(). */
.notice {
  display: none;
  margin-top: 10px;
  padding: 10px 12px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1.5;
}
.notice.show { display: block; }
.notice b { color: var(--text); }

/* -- Timeline chart ----------------------------------------- */
#timeline-canvas { display: block; width: 100%; border-radius: 6px; }
.chart-summary {
  margin: -4px 0 10px;
  color: var(--text-muted);
  font-size: 13px;
}

/* -- Toolbar ------------------------------------------------ */
.toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  padding-bottom: 12px;
  margin-bottom: 10px;
  border-bottom: 1px solid var(--border);
}
.toolbar-search {
  position: relative;
  flex: 1;
  min-width: 180px;
  max-width: 260px;
}
.toolbar-search input {
  width: 100%;
  padding: 6px 10px 6px 30px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface-2);
  color: var(--text);
  font-size: 13px;
  outline: none;
  transition: border-color var(--tr), box-shadow var(--tr);
  font-family: inherit;
}
.toolbar-search input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-dim);
}
.search-ico {
  position: absolute;
  left: 8px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-muted);
  pointer-events: none;
  width: 14px;
  height: 14px;
}
.sort-group {
  display: flex;
  gap: 4px;
  align-items: center;
  flex-wrap: wrap;
  font-size: 12px;
  color: var(--text-muted);
}
.sort-group label { margin-right: 2px; user-select: none; }
.sort-btn, .action-btn {
  padding: 4px 10px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-2);
  color: var(--text-muted);
  cursor: pointer;
  font-size: 12px;
  font-family: inherit;
  line-height: 1.5;
  transition: background var(--tr), color var(--tr), border-color var(--tr);
}
.sort-btn:hover, .action-btn:hover {
  background: var(--primary-dim);
  border-color: var(--primary);
  color: var(--primary);
}
.sort-btn.active {
  background: var(--primary-dim);
  border-color: var(--primary);
  color: var(--primary);
  font-weight: 600;
}
.toolbar-actions { display: flex; gap: 6px; margin-left: auto; }
.det-counter {
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 10px;
}

/* -- Detection cards ---------------------------------------- */
#detection-list { display: flex; flex-direction: column; gap: 10px; }
.detection {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  box-shadow: var(--shadow);
  overflow: hidden;
  transition: box-shadow var(--tr);
}
.detection:hover { box-shadow: var(--shadow-lg); }
.det-header {
  display: grid;
  grid-template-columns: 120px 1fr auto;
  gap: 12px;
  padding: 12px;
  align-items: start;
  cursor: pointer;
  user-select: none;
  transition: background var(--tr);
}
.det-header:hover { background: var(--surface-2); }
.det-thumb {
  width: 120px;
  height: 80px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--surface-2);
  flex-shrink: 0;
}
.det-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
.det-thumb .placeholder {
  width: 100%; height: 100%;
  display: flex; align-items: center; justify-content: center;
  color: var(--text-muted); font-size: 10px; text-align: center; padding: 6px;
}
.det-info { min-width: 0; }
.det-title {
  display: flex;
  align-items: baseline;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 5px;
}
.det-title .common { font-size: 16px; font-weight: 600; }
.det-title .sci { font-size: 12px; color: var(--text-muted); font-style: italic; }
.det-stats {
  display: flex;
  align-items: center;
  gap: 7px;
  flex-wrap: wrap;
  margin-bottom: 6px;
}
.links { display: flex; gap: 6px; flex-wrap: wrap; }
.links a {
  color: var(--primary);
  text-decoration: none;
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--primary-dim);
  font-weight: 500;
  transition: opacity var(--tr);
}
.links a:hover { opacity: .75; text-decoration: underline; }
.det-chevron {
  align-self: flex-start;
  margin-top: 6px;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  color: var(--text-muted);
  font-size: 14px;
  transition: transform var(--tr), color var(--tr);
  flex-shrink: 0;
}
.detection.collapsed .det-chevron { transform: rotate(-90deg); }
.det-body {
  border-top: 1px solid var(--border);
}
.detection.collapsed .det-body { display: none; }

/* -- Score / count pills ------------------------------------ */
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
.count-pill {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  background: var(--surface-2);
  color: var(--text-muted);
  border: 1px solid var(--border);
}

/* -- Occurrences -------------------------------------------- */
.occurrences {
  display: flex;
  flex-direction: column;
  padding: 6px 12px 10px;
}
.occurrence {
  padding: 7px 0;
  border-bottom: 1px dashed var(--border);
}
.occurrence:last-child { border-bottom: none; }
.occ-main {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.occ-time {
  font-size: 12px;
  color: var(--text-muted);
  font-variant-numeric: tabular-nums;
  min-width: 62px;
  flex-shrink: 0;
}
.occ-player {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 180px;
}
.native-audio { width: 100%; height: 32px; }
.player-js .native-audio { display: none; }
.audio-player { width: 100%; }
.custom-player { display: none; }
.player-js .custom-player {
  display: grid;
  grid-template-columns: auto minmax(80px, 1fr) auto;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 32px;
  padding: 4px 8px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface-2);
}
.player-btn {
  min-width: 54px;
  height: 24px;
  border: 0;
  border-radius: 6px;
  background: var(--primary);
  color: #fff;
  cursor: pointer;
  font: 600 12px/1 system-ui, sans-serif;
}
.player-range {
  --pct: 0%;
  width: 100%;
  min-width: 80px;
  accent-color: var(--primary);
  background: linear-gradient(to right, var(--primary) var(--pct), var(--border) var(--pct));
}
.player-time {
  color: var(--text-muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  min-width: 72px;
  text-align: right;
}
.occ-confirmed {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  background: var(--primary-dim);
  color: var(--primary);
}
/* Heard / seen pill on manually-entered occurrences. Neutral surface
   rather than the primary tint used by .occ-confirmed, so provenance
   reads as secondary to the confirm state. */
.occ-evidence {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  background: var(--surface-2);
  color: var(--text-muted);
}
.occ-note {
  margin-top: 6px;
  padding: 5px 10px;
  background: var(--surface-2);
  border-left: 3px solid var(--primary);
  border-radius: 0 6px 6px 0;
  font-size: 12px;
  color: var(--text);
  white-space: pre-wrap;
}

/* -- Empty state -------------------------------------------- */
.empty {
  color: var(--text-muted);
  font-style: italic;
  text-align: center;
  padding: 28px;
}

/* -- Map markers -------------------------------------------- */
.species-pin {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 1px 4px rgba(0,0,0,.4);
  background-size: cover;
  background-position: center;
  background-color: var(--surface-2);
}
.species-pin.fallback { background-color: #ff8a3d; }
.popup-card { display: flex; gap: 8px; align-items: center; min-width: 180px; }
.popup-card img { width: 60px; height: 40px; object-fit: cover; border-radius: 4px; }
.popup-card .pop-body b { display: block; font-size: 13px; }
.popup-card .pop-body i { color: #666; font-size: 11px; display: block; }
.popup-card .pop-body span { font-size: 12px; }

/* -- Footer ------------------------------------------------- */
footer {
  text-align: center;
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 36px;
  line-height: 2;
}
footer a { color: var(--primary); text-decoration: none; }
.footer-context {
  text-align: left;
  max-width: 960px;
  margin: 0 auto 14px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  line-height: 1.45;
}
.footer-context h2 {
  margin: 0 0 8px;
  color: var(--text);
  font-size: 13px;
  font-weight: 600;
}
.footer-context-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 8px 16px;
}
.footer-context-item .label {
  display: block;
  margin-bottom: 1px;
  color: var(--text-muted);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: .04em;
  text-transform: uppercase;
}
.footer-context-item .value {
  color: var(--text);
  font-size: 12px;
}

/* -- Print -------------------------------------------------- */
@media print {
  body { background: white; padding: 12px; }
  section.card, header.report, .detection { box-shadow: none !important; }
  #map, .map-fallback, #timeline-section { display: none !important; }
  audio, .toolbar { display: none !important; }
  /* Browser-specific troubleshooting hints are meaningless on paper. */
  .notice { display: none !important; }
  .detection.collapsed .det-body { display: block !important; }
}

/* -- Responsive --------------------------------------------- */
@media (max-width: 560px) {
  .det-header { grid-template-columns: 88px 1fr auto; }
  .det-thumb { width: 88px; height: 60px; }
  .toolbar-search { max-width: 100%; }
  .sort-group { display: none; }
  .player-js .custom-player { grid-template-columns: auto 1fr; }
  .player-time { grid-column: 1 / -1; text-align: left; }
}
</style>
</head>
<body>
<div class="container">

<header class="report">
  <h1>$title</h1>
  <div class="subtitle">$modeLabel &middot; $dt &middot; ${_esc(durationText)}</div>
  ${hasDetections ? '<div class="stats-bar">$statsBarHtml</div>' : ''}
  <div class="meta-grid">$metadataRows</div>
</header>

${hasDetections ? '''<section class="card" id="timeline-section">
  <h2>Detection timeline</h2>
  <div class="chart-summary" id="timeline-summary"></div>
  <canvas id="timeline-canvas" style="width:100%"></canvas>
</section>''' : ''}

${hasMap ? '''<section class="card">
  <div class="map-head">
    <h2>Map</h2>
    $osmLinkHtml
  </div>
  <div id="map"></div>
  <div class="notice" id="map-notice"></div>
  <noscript><div class="map-fallback">Enable JavaScript to view the interactive map.</div></noscript>
</section>''' : ''}

${audioFileName != null ? '''<section class="card">
  <h2>Full recording</h2>
  ${_buildAudioPlayer(Uri.encodeComponent(audioFileName))}
  <div class="notice audio-notice"></div>
</section>''' : ''}

<section class="card">
  <h2>Detections <span class="section-badge">${detections.length} total &middot; $speciesCount species</span></h2>
  <div class="notice audio-notice"></div>
  ${detections.isEmpty ? '<div class="empty">No detections recorded.</div>' : '''<div class="toolbar">
    <div class="toolbar-search">
      <svg class="search-ico" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
        <circle cx="6.5" cy="6.5" r="4.5"/>
        <line x1="10.2" y1="10.2" x2="14" y2="14"/>
      </svg>
      <input type="search" id="species-search" placeholder="Search species..." autocomplete="off">
    </div>
    <div class="sort-group">
      <label>Sort:</label>
      <button class="sort-btn active" data-sort="conf">Confidence</button>
      <button class="sort-btn" data-sort="time">First detected</button>
      <button class="sort-btn" data-sort="count">Count</button>
      <button class="sort-btn" data-sort="az">A-Z</button>
    </div>
    <div class="toolbar-actions">
      <button class="action-btn" id="expand-all">Expand all</button>
      <button class="action-btn" id="collapse-all">Collapse all</button>
    </div>
  </div>
  <div class="det-counter" id="det-counter">$speciesCount species</div>
  <div id="detection-list">$detectionsHtml</div>'''}
</section>

${settingsRows.isEmpty ? '' : '''<section class="card">
  <h2>Recording settings</h2>
  <div class="meta-grid">$settingsRows</div>
</section>'''}

${extendedRows.isEmpty ? '' : '''<section class="card">
  <h2>Session details</h2>
  <div class="meta-grid">$extendedRows</div>
</section>'''}

<footer>
  $footerContextHtml
  Generated by <a href="https://birdnet.cornell.edu" target="_blank" rel="noopener">BirdNET Live</a> &middot;
  Species data &amp; images &copy; <a href="https://birdnet.cornell.edu" target="_blank" rel="noopener">Cornell Lab of Ornithology</a>${hasMap ? ' &middot; Map &copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors' : ''}
</footer>

</div>

<script>window.SESSION_DATA = $dataJson;</script>
${hasMap ? '<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" defer></script>' : ''}
<script defer>
/* -- Timeline bar chart ------------------------------------------ */
function initTimeline() {
  var el = document.getElementById('timeline-canvas');
  if (!el) return;
  var timeline = (window.SESSION_DATA || {}).timeline;
  var bins = timeline && timeline.bins;
  if (!bins || !bins.length) {
    var sec = document.getElementById('timeline-section');
    if (sec) sec.style.display = 'none';
    return;
  }
  var maxN = bins.reduce(function(m, n) { return n > m ? n : m; }, 0);
  if (!maxN) {
    var sec2 = document.getElementById('timeline-section');
    if (sec2) sec2.style.display = 'none';
    return;
  }
  var binSeconds = Math.max(1, timeline.binSeconds || 1);
  var durationSeconds = Math.max(binSeconds * bins.length, timeline.durationSeconds || 0);
  var summary = document.getElementById('timeline-summary');
  if (summary) {
    summary.textContent =
      (timeline.total || 0) + ' detections across ' + fmtDuration(durationSeconds) +
      ' (' + fmtDuration(binSeconds) + ' bins, peak ' + maxN + ')';
  }
  var dpr = window.devicePixelRatio || 1;
  var W = el.parentElement.clientWidth || 600;
  var H = 86;
  el.width = Math.round(W * dpr);
  el.height = Math.round(H * dpr);
  el.style.height = H + 'px';
  var g = el.getContext('2d');
  g.scale(dpr, dpr);
  var nb = bins.length;
  var bw = W / nb;
  g.clearRect(0, 0, W, H);
  g.strokeStyle = 'rgba(128,128,128,0.25)';
  g.lineWidth = 1;
  g.beginPath();
  g.moveTo(0, H - 24.5);
  g.lineTo(W, H - 24.5);
  g.stroke();
  bins.forEach(function(n, i) {
    if (!n) return;
    var frac = n / maxN;
    var bh = Math.max(2, Math.round(frac * (H - 32)));
    var x = i * bw + 0.5;
    var bwInner = Math.max(1, bw - 1);
    var gr = g.createLinearGradient(0, H - 24 - bh, 0, H - 24);
    gr.addColorStop(0, 'rgba(' + (79 + Math.round(176 * frac)) + ',' +
      (155 + Math.round(46 * frac)) + ',' + (255 - Math.round(200 * frac)) + ',0.9)');
    gr.addColorStop(1, 'rgba(79,155,255,0.3)');
    g.fillStyle = gr;
    g.fillRect(x, H - 24 - bh, bwInner, bh);
    if (bw > 18) {
      g.fillStyle = 'rgba(128,128,128,0.85)';
      g.font = '10px system-ui, sans-serif';
      g.textAlign = 'center';
      g.fillText(String(n), x + bwInner / 2, Math.max(10, H - 27 - bh));
    }
  });
  g.fillStyle = 'rgba(128,128,128,0.7)';
  g.font = '10px system-ui, sans-serif';
  function lbl(seconds, x, align) {
    var txt = fmtDuration(seconds);
    g.textAlign = align;
    g.fillText(txt, x, H - 6);
  }
  lbl(0, 0, 'left');
  if (nb > 4) lbl(Math.floor(durationSeconds / 2), W / 2, 'center');
  lbl(durationSeconds, W, 'right');
}

/* -- Map (Leaflet) ----------------------------------------------- */
function showMapNotice(html) {
  var n = document.getElementById('map-notice');
  if (!n || n.classList.contains('show')) return;
  n.innerHTML = html;
  n.classList.add('show');
}

function initMap() {
  /* Leaflet is loaded from a CDN. Offline, or behind a network that blocks
     unpkg, it simply never defines L — degrade to a message plus the static
     OpenStreetMap link that sits next to the heading. */
  if (typeof L === 'undefined') {
    var el = document.getElementById('map');
    if (el) el.outerHTML = '<div class="map-fallback">The interactive map could not be loaded (no internet connection, or the map library was blocked).</div>';
    showMapNotice('<b>Map unavailable.</b> Use the &ldquo;View on OpenStreetMap&rdquo; link above to see this location in your browser.');
    return;
  }
  var data = window.SESSION_DATA;
  var map = L.map('map', { zoomControl: true });
  var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    /* Opened from file:// there is no meaningful referrer to send, and
       browsers disagree on what they invent instead — Firefox has been seen
       taking 403s from the tile server where Chromium is served normally.
       Declaring no-referrer makes the request identical everywhere, so the
       report behaves the same in every browser. */
    referrerPolicy: 'no-referrer',
    attribution: '\xa9 OpenStreetMap contributors'
  }).addTo(map);

  /* Tiles are fetched per-viewport, so a block shows up as repeated tileerror
     events rather than one failure. A couple of errors is normal at the edge
     of the world or on a flaky connection; a run of them means the tile
     service is genuinely unreachable and the user needs a way out. */
  var tileErrors = 0;
  tiles.on('tileerror', function() {
    tileErrors++;
    if (tileErrors < 4) return;
    showMapNotice(
      '<b>Map tiles could not be loaded.</b> The pins and track below are still ' +
      'positioned correctly, but the background imagery was blocked. This ' +
      'usually happens when the report is opened directly from a file — try a ' +
      'different browser, or use the &ldquo;View on OpenStreetMap&rdquo; link above.');
  });
  tiles.on('load', function() { tileErrors = 0; });

  var bounds = L.latLngBounds([]);
  if (data.track && data.track.length) {
    var poly = L.polyline(data.track.map(function(p) { return [p[0], p[1]]; }),
      { color: '#0d6efd', weight: 4, opacity: 0.8 }).addTo(map);
    bounds.extend(poly.getBounds());
  }
  if (data.detections) {
    data.detections.forEach(function(d) {
      if (d.lat == null || d.lon == null) return;
      var icon = L.divIcon({
        className: '',
        html: d.img
          ? '<div class="species-pin" style="background-image:url(\\'' + d.img + '\\')"></div>'
          : '<div class="species-pin fallback"></div>',
        iconSize: [36, 36], iconAnchor: [18, 18], popupAnchor: [0, -20]
      });
      var m = L.marker([d.lat, d.lon], { icon: icon }).addTo(map);
      var popup = '<div class="popup-card">'
        + (d.img ? '<img src="' + d.img + '" alt="">' : '')
        + '<div class="pop-body"><b>' + escHtml(d.common) + '</b>'
        + '<i>' + escHtml(d.sci) + '</i>'
        + '<span>' + Math.round(d.conf * 100) + '%</span></div></div>';
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
}

/* -- Detection toggle -------------------------------------------- */
function toggleDet(card) {
  card.classList.toggle('collapsed');
}

/* -- Search / sort / expand -------------------------------------- */
function initDetections() {
  var search = document.getElementById('species-search');
  if (search) search.addEventListener('input', filterDetections);

  document.querySelectorAll('.sort-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.sort-btn').forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      sortDetections(btn.dataset.sort);
    });
  });

  var ea = document.getElementById('expand-all');
  if (ea) ea.addEventListener('click', function() {
    document.querySelectorAll('#detection-list .detection').forEach(function(d) {
      d.classList.remove('collapsed');
    });
  });
  var ca = document.getElementById('collapse-all');
  if (ca) ca.addEventListener('click', function() {
    document.querySelectorAll('#detection-list .detection').forEach(function(d) {
      d.classList.add('collapsed');
    });
  });

  sortDetections('conf');
  filterDetections();
}

function filterDetections() {
  var input = document.getElementById('species-search');
  var q = (input ? input.value : '').toLowerCase().trim();
  var list = document.getElementById('detection-list');
  if (!list) return;
  var cards = list.querySelectorAll('.detection');
  var visible = 0;
  cards.forEach(function(c) {
    var show = !q
      || (c.dataset.common || '').indexOf(q) >= 0
      || (c.dataset.sci || '').indexOf(q) >= 0;
    c.style.display = show ? '' : 'none';
    if (show) visible++;
  });
  var counter = document.getElementById('det-counter');
  if (counter) {
    var total = cards.length;
    counter.textContent = visible === total
      ? total + ' species'
      : visible + ' of ' + total + ' species';
  }
}

function sortDetections(by) {
  var list = document.getElementById('detection-list');
  if (!list) return;
  var cards = Array.from(list.querySelectorAll(':scope > .detection'));
  cards.sort(function(a, b) {
    var audioDiff = (b.dataset.hasAudio === '1' ? 1 : 0) -
      (a.dataset.hasAudio === '1' ? 1 : 0);
    if (audioDiff) return audioDiff;
    if (by === 'count') return parseInt(b.dataset.count || '0') - parseInt(a.dataset.count || '0');
    if (by === 'conf')  return parseFloat(b.dataset.conf || '0') - parseFloat(a.dataset.conf || '0');
    if (by === 'az')    return (a.dataset.common || '').localeCompare(b.dataset.common || '');
    if (by === 'time') return parseInt(a.dataset.time || '0') - parseInt(b.dataset.time || '0');
    return parseFloat(b.dataset.conf || '0') - parseFloat(a.dataset.conf || '0');
  });
  cards.forEach(function(c) { list.appendChild(c); });
}

/* ---- Audio players ------------------------------------------------------- */
/* The report references its audio by relative filename, so playback only works
   when the sibling files are actually on disk next to it. The common failure is
   opening report.html straight out of the .zip: Windows Explorer (and most
   archive viewers) extract only the file you double-clicked to a temp folder
   and leave the audio behind, so every src 404s with no explanation. Rather
   than warn everybody up front, watch for the first real load error and explain
   it then — the message is only shown to people who actually hit it. */
function showAudioNotice() {
  var html =
    '<b>Audio files could not be found.</b> If you opened this report from ' +
    'inside a .zip archive, extract the whole archive to a folder first and ' +
    'then open the report again &mdash; the recordings have to sit next to ' +
    'the report file for playback to work.';
  /* One notice per audio-bearing card (full recording, detection clips), so the
     explanation appears wherever the user pressed Play. */
  document.querySelectorAll('.audio-notice').forEach(function(n) {
    if (n.classList.contains('show')) return;
    n.innerHTML = html;
    n.classList.add('show');
  });
}

function initAudioPlayers() {
  document.querySelectorAll('.audio-player').forEach(function(player) {
    var audio = player.querySelector('audio');
    var btn = player.querySelector('.player-btn');
    var range = player.querySelector('.player-range');
    var time = player.querySelector('.player-time');
    if (!audio || !btn || !range || !time) return;

    function update() {
      var duration = isFinite(audio.duration) ? audio.duration : 0;
      var current = isFinite(audio.currentTime) ? audio.currentTime : 0;
      var pct = duration > 0 ? Math.max(0, Math.min(100, current / duration * 100)) : 0;
      range.value = String(pct);
      range.style.setProperty('--pct', pct + '%');
      time.textContent = fmtClock(current) + ' / ' + (duration > 0 ? fmtClock(duration) : '--:--');
    }

    btn.addEventListener('click', function() {
      if (audio.paused) {
        document.querySelectorAll('.audio-player audio').forEach(function(other) {
          if (other !== audio) other.pause();
        });
        audio.play();
      } else {
        audio.pause();
      }
    });

    range.addEventListener('input', function() {
      var duration = isFinite(audio.duration) ? audio.duration : 0;
      if (duration > 0) audio.currentTime = duration * (parseFloat(range.value) / 100);
      update();
    });

    audio.addEventListener('loadedmetadata', update);
    audio.addEventListener('timeupdate', update);
    /* Fires when the source is missing or undecodable. Because the players use
       preload="none", this only happens once the user actually presses Play,
       which is exactly the moment the explanation is useful. */
    audio.addEventListener('error', function() {
      btn.textContent = 'Play';
      btn.setAttribute('aria-pressed', 'false');
      btn.disabled = true;
      time.textContent = 'Unavailable';
      showAudioNotice();
    });
    audio.addEventListener('play', function() {
      btn.textContent = 'Pause';
      btn.setAttribute('aria-pressed', 'true');
    });
    audio.addEventListener('pause', function() {
      btn.textContent = 'Play';
      btn.setAttribute('aria-pressed', 'false');
    });
    audio.addEventListener('ended', function() {
      btn.textContent = 'Play';
      btn.setAttribute('aria-pressed', 'false');
      update();
    });
    update();
  });
}

/* -- Utility ----------------------------------------------------- */
function escHtml(s) {
  return String(s).replace(/[&<>"']/g, function(c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}

function fmtClock(seconds) {
  seconds = Math.max(0, Math.floor(seconds || 0));
  var h = Math.floor(seconds / 3600);
  var m = Math.floor((seconds % 3600) / 60);
  var s = seconds % 60;
  if (h > 0) return h + ':' + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  return m + ':' + String(s).padStart(2, '0');
}

function fmtDuration(seconds) {
  seconds = Math.max(0, Math.round(seconds || 0));
  var h = Math.floor(seconds / 3600);
  var m = Math.floor((seconds % 3600) / 60);
  var s = seconds % 60;
  if (h > 0) return h + 'h ' + m + 'm';
  if (m > 0) return m + 'm ' + s + 's';
  return s + 's';
}

/* -- Boot -------------------------------------------------------- */
window.addEventListener('load', function() {
  initTimeline();
  ${hasMap ? 'initMap();' : ''}
  initDetections();
  initAudioPlayers();
});
</script>
</body>
</html>
''';
}

// -- Data payload ------------------------------------------------------------

String _buildDataPayload(
  LiveSession session, {
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  final dets = <Map<String, dynamic>>[];
  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final encodedSci = Uri.encodeComponent(d.scientificName);
    final clipName = clipFileMap?[i];
    dets.add({
      'common': _localizedCommon(d, taxonomy, speciesLocale),
      'sci':
          taxonomy?.displayScientificName(d.scientificName) ?? d.scientificName,
      'conf': d.confidence,
      'lat': d.latitude,
      'lon': d.longitude,
      'clip': clipName != null ? Uri.encodeComponent(clipName) : null,
      'img':
          'https://birdnet.cornell.edu/taxonomy/api/image/$encodedSci?size=thumb',
    });
  }

  final track = session.gpsTrack.map((p) => [p.latitude, p.longitude]).toList();
  final center = _sessionCenter(session);

  final timeline = _buildTimelinePayload(session);

  return jsonEncode({
    'detections': dets,
    'track': track,
    if (center != null) 'center': [center.$1, center.$2],
    if (timeline != null) 'timeline': timeline,
  });
}

Map<String, dynamic>? _buildTimelinePayload(LiveSession session) {
  if (session.detections.isEmpty) return null;

  final durationSeconds = _timelineDurationSeconds(session);
  if (durationSeconds <= 0) return null;

  final targetBins =
      durationSeconds <= 60
          ? durationSeconds
          : durationSeconds <= 600
          ? 20
          : durationSeconds <= 3600
          ? 30
          : 48;
  final binCount = targetBins.clamp(1, 48).toInt();
  final binSeconds =
      (durationSeconds / binCount).ceil().clamp(1, 86400).toInt();
  final actualBins = (durationSeconds / binSeconds).ceil().clamp(1, 48).toInt();
  final bins = List<int>.filled(actualBins, 0, growable: false);

  for (final d in session.detections) {
    final offset = session.trimmedRelative(d.timestamp);
    final clampedOffset = offset.clamp(0, durationSeconds.toDouble());
    final index =
        (clampedOffset / binSeconds).floor().clamp(0, actualBins - 1).toInt();
    bins[index]++;
  }

  return {
    'bins': bins,
    'binSeconds': binSeconds,
    'durationSeconds': durationSeconds,
    'total': session.detections.length,
  };
}

int _timelineDurationSeconds(LiveSession session) {
  // Offsets in the report index the exported audio, so a trimmed session
  // measures its timeline from the trim start.
  var durationSeconds = session.trimmedTimelineSeconds.round();
  for (final d in session.detections) {
    final offset = session.trimmedRelative(d.timestamp).ceil();
    if (offset + 1 > durationSeconds) {
      durationSeconds = offset + 1;
    }
  }
  return durationSeconds <= 0 ? 1 : durationSeconds;
}

// -- Detection cards ---------------------------------------------------------

String _buildDetectionsHtml(
  LiveSession session, {
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  if (session.detections.isEmpty) return '';
  final timeFmt = DateFormat('HH:mm:ss');

  // Group detections by scientific name.
  final indices = <String, List<int>>{};
  for (var i = 0; i < session.detections.length; i++) {
    final sci = session.detections[i].scientificName;
    indices.putIfAbsent(sci, () => []).add(i);
  }
  final speciesStats =
      <String, ({bool hasAudio, double bestConf, DateTime firstTime})>{};
  for (final entry in indices.entries) {
    var hasAudio = false;
    var bestConf = 0.0;
    var firstTime = session.detections[entry.value.first].timestamp;
    for (final i in entry.value) {
      final d = session.detections[i];
      if (clipFileMap?[i] != null) hasAudio = true;
      if (d.confidence > bestConf) bestConf = d.confidence;
      if (d.timestamp.isBefore(firstTime)) firstTime = d.timestamp;
    }
    speciesStats[entry.key] = (
      hasAudio: hasAudio,
      bestConf: bestConf,
      firstTime: firstTime,
    );
  }

  // Default order matches the toolbar: species with audio first, then
  // highest-confidence species.
  final orderedSpecies =
      indices.keys.toList()..sort((a, b) {
        final sa = speciesStats[a]!;
        final sb = speciesStats[b]!;
        final audioCompare = (sb.hasAudio ? 1 : 0) - (sa.hasAudio ? 1 : 0);
        if (audioCompare != 0) return audioCompare;
        final confCompare = sb.bestConf.compareTo(sa.bestConf);
        if (confCompare != 0) return confCompare;
        return sa.firstTime.compareTo(sb.firstTime);
      });

  final buf = StringBuffer();
  for (final sci in orderedSpecies) {
    final ids = indices[sci]!;
    final firstDet = session.detections[ids.first];
    final common = _localizedCommon(firstDet, taxonomy, speciesLocale);

    final stats = speciesStats[sci]!;
    final bestConf = stats.bestConf;
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

    // data-time as Unix milliseconds for JS sort.
    final timeMs = stats.firstTime.millisecondsSinceEpoch;

    buf.writeln(
      '<div class="detection collapsed"'
      ' data-sci="${_esc(sci.toLowerCase())}"'
      ' data-common="${_esc(common.toLowerCase())}"'
      ' data-count="${ids.length}"'
      ' data-conf="${bestConf.toStringAsFixed(4)}"'
      ' data-has-audio="${stats.hasAudio ? '1' : '0'}"'
      ' data-time="$timeMs">',
    );
    // -- Header (always visible, click to toggle) ------------------
    buf.writeln(
      '  <div class="det-header" onclick="toggleDet(this.closest(\'.detection\'))">',
    );
    buf.writeln('    <div class="det-thumb">');
    buf.writeln(
      '      <img src="${_esc(imgUrl)}" alt="${_esc(common)}"'
      ' onerror="this.outerHTML=\'<div class=&quot;placeholder&quot;>No image</div>\'">',
    );
    buf.writeln('    </div>');
    buf.writeln('    <div class="det-info">');
    buf.writeln('      <div class="det-title">');
    buf.writeln('        <span class="common">${_esc(common)}</span>');
    buf.writeln('        <span class="sci">${_esc(sci)}</span>');
    buf.writeln('      </div>');
    buf.writeln('      <div class="det-stats">');
    buf.writeln('        <span class="score $bestClass">$bestPct%</span>');
    buf.writeln(
      '        <span class="count-pill">'
      '${ids.length} ${ids.length == 1 ? 'detection' : 'detections'}'
      '</span>',
    );
    buf.writeln('      </div>');
    if (ebirdUrl != null || inatUrl != null || wikiUrl != null) {
      buf.writeln(
        '      <div class="links" onclick="event.stopPropagation()">',
      );
      if (ebirdUrl != null) {
        buf.writeln(
          '        <a href="${_esc(ebirdUrl)}" target="_blank" rel="noopener">eBird</a>',
        );
      }
      if (inatUrl != null) {
        buf.writeln(
          '        <a href="${_esc(inatUrl)}" target="_blank" rel="noopener">iNaturalist</a>',
        );
      }
      if (wikiUrl != null) {
        buf.writeln(
          '        <a href="${_esc(wikiUrl)}" target="_blank" rel="noopener">Wikipedia</a>',
        );
      }
      buf.writeln('      </div>');
    }
    buf.writeln('    </div>');
    buf.writeln(
      '    <span class="det-chevron" aria-hidden="true">&#9662;</span>',
    );
    buf.writeln('  </div>');

    // -- Collapsible body ------------------------------------------
    buf.writeln('  <div class="det-body">');
    buf.writeln('    <div class="occurrences">');
    final orderedIds =
        ids.toList()..sort((a, b) {
          final aHasAudio = clipFileMap?[a] != null;
          final bHasAudio = clipFileMap?[b] != null;
          final audioCompare = (bHasAudio ? 1 : 0) - (aHasAudio ? 1 : 0);
          if (audioCompare != 0) return audioCompare;
          final confCompare = session.detections[b].confidence.compareTo(
            session.detections[a].confidence,
          );
          if (confCompare != 0) return confCompare;
          return session.detections[a].timestamp.compareTo(
            session.detections[b].timestamp,
          );
        });
    for (final i in orderedIds) {
      final d = session.detections[i];
      final confPct = (d.confidence * 100).round();
      final scoreClass =
          d.confidence >= 0.7 ? 'high' : (d.confidence < 0.4 ? 'low' : '');
      final relSec = session.trimmedRelative(d.timestamp).round();
      final relText = _fmtRelative(relSec);
      final wallText = timeFmt.format(d.timestamp.toLocal());
      final clipNameRaw = clipFileMap?[i];
      final clipNameEncoded =
          clipNameRaw != null ? Uri.encodeComponent(clipNameRaw) : null;
      final noteTrimmed = d.note?.trim() ?? '';
      final hasNote = noteTrimmed.isNotEmpty;

      buf.writeln('      <div class="occurrence">');
      buf.writeln('        <div class="occ-main">');
      buf.writeln('          <span class="occ-time">${_esc(wallText)}</span>');
      buf.writeln('          <span class="score $scoreClass">$confPct%</span>');
      if (clipNameEncoded != null) {
        buf.writeln('          <div class="occ-player">');
        buf.writeln('            ${_buildAudioPlayer(clipNameEncoded)}');
        buf.writeln('          </div>');
      } else {
        buf.writeln(
          '          <span style="color:var(--text-muted)">${_esc(relText)}</span>',
        );
      }
      final evidenceText = switch (d.evidence) {
        DetectionEvidence.heard => 'Heard',
        DetectionEvidence.seen => 'Seen',
        DetectionEvidence.heardAndSeen => 'Heard and seen',
        null => null,
      };
      if (evidenceText != null) {
        buf.writeln(
          '          <span class="occ-evidence">${_esc(evidenceText)}</span>',
        );
      }
      if (d.isConfirmed) {
        buf.writeln('          <span class="occ-confirmed">Confirmed</span>');
      }
      buf.writeln('        </div>');
      if (hasNote) {
        buf.writeln('        <div class="occ-note">${_esc(noteTrimmed)}</div>');
      }
      buf.writeln('      </div>');
    }
    buf.writeln('    </div>');
    buf.writeln('  </div>');
    buf.writeln('</div>');
  }
  return buf.toString();
}

String _buildAudioPlayer(String encodedSrc) {
  final safeSrc = _esc(encodedSrc);
  return '<div class="audio-player">'
      '<audio class="native-audio" controls preload="none" src="$safeSrc"></audio>'
      '<div class="custom-player" aria-hidden="false">'
      '<button class="player-btn" type="button" aria-pressed="false">Play</button>'
      '<input class="player-range" type="range" min="0" max="100" value="0" step="0.1" aria-label="Playback position">'
      '<span class="player-time">0:00 / --:--</span>'
      '</div>'
      '</div>';
}

String _buildFooterContextHtml(
  LiveSession session,
  Map<String, dynamic>? metadata,
) {
  final items = <(String, String)>[];

  final app = _mapAt(metadata, 'app');
  final appVersion = _stringAt(app, 'version');
  final buildNumber = _stringAt(app, 'buildNumber');
  if (appVersion != null || buildNumber != null) {
    items.add((
      'App',
      [
        if (appVersion != null) 'v$appVersion',
        if (buildNumber != null) 'build $buildNumber',
      ].join(' '),
    ));
  }

  final audioModel = _mapAt(metadata, 'audioModel');
  final audioModelText = _modelSummary(
    audioModel,
    fallbackName: 'Audio classifier',
    includeSampleRate: true,
  );
  if (audioModelText != null) {
    items.add(('Audio model', audioModelText));
  }

  final geoModel = _mapAt(metadata, 'geoModel');
  final geoModelText = _modelSummary(geoModel, fallbackName: 'Geo model');
  if (geoModelText != null) {
    items.add(('Geo model', geoModelText));
  }

  items.add(('Analysis settings', _analysisSettingsSummary(session, metadata)));

  if (items.isEmpty) return '';
  final rows =
      items
          .map(
            (item) =>
                '<div class="footer-context-item">'
                '<span class="label">${_esc(item.$1)}</span>'
                '<span class="value">${_esc(item.$2)}</span>'
                '</div>',
          )
          .join();
  return '<div class="footer-context">'
      '<h2>Analysis context</h2>'
      '<div class="footer-context-grid">$rows</div>'
      '</div>';
}

String? _modelSummary(
  Map<String, dynamic>? model, {
  required String fallbackName,
  bool includeSampleRate = false,
}) {
  if (model == null || model.isEmpty) return null;
  final name = _stringAt(model, 'name') ?? fallbackName;
  final version = _stringAt(model, 'version');
  final speciesCount = _numAt(model, 'speciesCount')?.round();
  final audio = _mapAt(model, 'audio');
  final sampleRate = _numAt(audio, 'sampleRate')?.round();

  return [
    name,
    if (version != null) 'v$version',
    if (speciesCount != null) '$speciesCount species',
    if (includeSampleRate && sampleRate != null) '$sampleRate Hz',
  ].join(' | ');
}

String _analysisSettingsSummary(
  LiveSession session,
  Map<String, dynamic>? metadata,
) {
  final analysis = _mapAt(_mapAt(metadata, 'settings'), 'analysis');
  final s = session.settings;
  final windowSeconds =
      _numAt(analysis, 'windowDurationSeconds')?.round() ?? s.windowDuration;
  final confidenceThreshold =
      _numAt(analysis, 'confidenceThresholdPercent')?.round() ??
      s.confidenceThreshold;
  final inferenceRate =
      _numAt(analysis, 'inferenceRateHz')?.toDouble() ?? s.inferenceRate;
  final sensitivity =
      _numAt(analysis, 'sensitivity')?.toDouble() ?? s.sensitivity;

  // The HTML report deliberately surfaces only the core analysis parameters.
  // Pooling / support-gate / audio-preprocessing details live in the exported
  // JSON metadata side-file instead of cluttering the human-readable report.
  return [
    '${windowSeconds}s window',
    '$confidenceThreshold% min confidence',
    '${_fmtNumber(inferenceRate)} Hz',
    if (sensitivity != null) 'sensitivity ${_fmtNumber(sensitivity)}',
  ].join(' | ');
}

// -- Metadata rows ------------------------------------------------------------

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
      rows.add(('Temperature', '${w.temperatureC!.toStringAsFixed(1)} deg C'));
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
  return _renderMetaRows(rows);
}

String _buildSettingsRows(LiveSession session) {
  final s = session.settings;
  // Only the core analysis parameters are shown in the report. The full set
  // (pooling mode + support-gate knobs, gain, high-pass, clip context, species
  // filter, …) is preserved in the exported JSON metadata side-file.
  final rows = <(String, String)>[];
  rows.add(('Window', '${s.windowDuration} s'));
  rows.add(('Min confidence', '${s.confidenceThreshold}%'));
  rows.add(('Inference rate', '${s.inferenceRate}x'));
  if (s.sensitivity != null) {
    rows.add(('Sensitivity', s.sensitivity!.toStringAsFixed(2)));
  }
  return _renderMetaRows(rows);
}

/// Extended session details shown at the bottom (session ID, end time, etc.).
String _buildExtendedMetaRows(LiveSession session) {
  final rows = <(String, String)>[];
  rows.add(('Session ID', session.id));
  if (session.endTime != null) {
    rows.add((
      'End time',
      DateFormat('HH:mm:ss').format(session.endTime!.toLocal()),
    ));
  }
  if (session.stopReason != null) {
    rows.add(('Stop reason', _stopReasonLabel(session.stopReason)));
  }
  final recorded = session.recordedDurationSeconds;
  if (recorded != null && recorded > 0) {
    rows.add(('Recorded', _fmtDuration(Duration(seconds: recorded))));
  }
  if (session.sessionNumber != null) {
    rows.add(('Session #', session.sessionNumber.toString()));
  }
  return _renderMetaRows(rows);
}

String _renderMetaRows(List<(String, String)> rows) {
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

// -- Helpers ------------------------------------------------------------------

/// Builds the "View on OpenStreetMap" link shown beside the Map heading.
///
/// Deliberately a static `<a>` rather than something rendered by the map
/// script: its whole job is to still work when Leaflet or the tile service
/// does not. Returns an empty string when the session has no usable position.
String _buildOsmLinkHtml((double, double)? center) {
  if (center == null) return '';
  final lat = center.$1.toStringAsFixed(5);
  final lon = center.$2.toStringAsFixed(5);
  final url = 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=14/$lat/$lon';
  return '<a class="map-osm-link" href="${_esc(url)}" target="_blank" '
      'rel="noopener">View on OpenStreetMap &rarr;</a>';
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

String _stopReasonLabel(SessionStopReason? reason) {
  switch (reason) {
    case SessionStopReason.manual:
      return 'Manual stop';
    case SessionStopReason.maxDuration:
      return 'Max duration reached';
    case SessionStopReason.lowBattery:
      return 'Low battery';
    case null:
      return '';
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
  return neg ? '-$body' : '+$body';
}

Map<String, dynamic>? _mapAt(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

String? _stringAt(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  if (value == null) return null;
  return value.toString();
}

num? _numAt(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is num ? value : null;
}

String _fmtNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
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
