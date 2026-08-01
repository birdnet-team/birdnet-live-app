// =============================================================================
// Offline Map Download Tile (Settings → Location)
// =============================================================================
//
// Lets users pre-download map tiles for an area centered on their current GPS
// fix. The implementation is currently hidden from Settings while BirdNET Live
// uses the public OpenStreetMap tile service, because that service does not
// allow bulk prefetching or offline map-download features. Keep this flow
// available only for a future tile source that explicitly permits offline use.
//
// Pragmatic choices:
//
//   • Zoom range 12–16. Anything coarser than 12 is only a few KB
//     per area (so already cached by casual use), and 16 is the
//     finest level the survey map hits in practice.
//   • Radius: 1 / 5 / 10 / 25 km picker. We compute an estimate
//     before downloading and refuse anything > 50 MB so an allowed tile
//     provider is still used gently.
//   • Concurrency: 4 in-flight tile fetches with a 500 ms minimum
//     spacing between *bursts* of 4, so we hold under the 2 req/s
//     OSM tile-usage rule averaged across the whole batch.
//   • Cancel anytime; progress bar is linear.
//
// The math (lon/lat → tile x/y) is the standard slippy-map formula —
// no flutter_map dependency needed for the calculation, only for the
// shared cache.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../core/services/location_service.dart';
import '../../features/explore/explore_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/open_street_map_tile_layer.dart';

/// Bounding zoom range we seed for offline use.
const int _minZoom = 12;
const int _maxZoom = 16;

/// Average measured tile size, used for the pre-download estimate. Real
/// tiles vary 5–60 KB; 30 KB is a tidy upper-middle estimate that
/// rarely under-promises.
const int _avgTileBytes = 30 * 1024;

/// Hard cap per OSM tile-usage policy.
const int _maxBundleBytes = 50 * 1024 * 1024;

/// Number of concurrent in-flight downloads. Combined with the 500 ms
/// pacing in [_downloadAll] this keeps us under ~8 req/s peak and
/// well under 2 req/s sustained.
const int _concurrency = 4;

/// Settings → Location tile that opens the offline-map download flow.
class OfflineMapDownloadTile extends ConsumerWidget {
  const OfflineMapDownloadTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(AppIcons.downloadForOffline),
      title: Text(l10n.settingsOfflineMapDownload),
      subtitle: Text(l10n.settingsOfflineMapDownloadSubtitle),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => _start(context, ref),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Always grab a fresh GPS fix (the cached one in
    // currentLocationProvider may be stale, sometimes by miles). Routed
    // through LocationService so the "Use GPS" setting is honoured.
    AppLocation? pos;
    try {
      pos = await ref
          .read(locationServiceProvider)
          .getCurrentLocation(maxAge: Duration.zero);
    } catch (_) {
      pos = null;
    }
    if (pos == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsGpsRefreshFailed)),
      );
      return;
    }

    if (!context.mounted) return;
    final config = await showDialog<_DownloadConfig>(
      context: context,
      builder:
          (_) => _RadiusPickerDialog(
            latitude: pos!.latitude,
            longitude: pos.longitude,
          ),
    );
    if (config == null || !context.mounted) return;

    if (config.estimatedBytes > _maxBundleBytes) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsOfflineMapTooLarge)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(config: config),
    );
  }
}

// ---------------------------------------------------------------------------
// Slippy-map math
// ---------------------------------------------------------------------------

/// Standard lon/lat → tile x/y (Web Mercator).
({int x, int y}) _lonLatToTile(double lon, double lat, int z) {
  final n = 1 << z;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  final latRad = lat * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
              2.0 *
              n)
          .floor();
  return (x: x.clamp(0, n - 1), y: y.clamp(0, n - 1));
}

/// Approximate width of one tile at [lat] and zoom [z], in kilometers.
double _tileWidthKm(double lat, int z) {
  final n = 1 << z;
  return 40075.0 * math.cos(lat * math.pi / 180.0) / n;
}

/// Returns every tile coordinate inside the bounding square of
/// [radiusKm] around (lat, lon) for zoom levels [_minZoom].._maxZoom.
List<({int z, int x, int y})> _tilesForArea(
  double lat,
  double lon,
  double radiusKm,
) {
  final out = <({int z, int x, int y})>[];
  for (var z = _minZoom; z <= _maxZoom; z++) {
    final tileKm = _tileWidthKm(lat, z);
    final span = (radiusKm / tileKm).ceil();
    final center = _lonLatToTile(lon, lat, z);
    final n = 1 << z;
    for (var dx = -span; dx <= span; dx++) {
      for (var dy = -span; dy <= span; dy++) {
        final x = center.x + dx;
        final y = center.y + dy;
        if (x < 0 || x >= n || y < 0 || y >= n) continue;
        out.add((z: z, x: x, y: y));
      }
    }
  }
  return out;
}

String _tileUrl(int z, int x, int y) =>
    'https://tile.openstreetmap.org/$z/$x/$y.png';

class _DownloadConfig {
  const _DownloadConfig({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.tiles,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final List<({int z, int x, int y})> tiles;

  int get estimatedBytes => tiles.length * _avgTileBytes;
}

// ---------------------------------------------------------------------------
// Radius picker dialog
// ---------------------------------------------------------------------------

class _RadiusPickerDialog extends StatefulWidget {
  const _RadiusPickerDialog({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  State<_RadiusPickerDialog> createState() => _RadiusPickerDialogState();
}

class _RadiusPickerDialogState extends State<_RadiusPickerDialog> {
  static const _radiiKm = [1, 5, 10, 25];
  int _selected = 5;

  _DownloadConfig _buildConfig() {
    final tiles = _tilesForArea(
      widget.latitude,
      widget.longitude,
      _selected.toDouble(),
    );
    return _DownloadConfig(
      latitude: widget.latitude,
      longitude: widget.longitude,
      radiusKm: _selected.toDouble(),
      tiles: tiles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = _buildConfig();
    final mb = (config.estimatedBytes / (1024 * 1024)).toStringAsFixed(1);
    final tooLarge = config.estimatedBytes > _maxBundleBytes;

    return AlertDialog(
      title: Text(l10n.settingsOfflineMapDownload),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsOfflineMapRadiusLabel),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final r in _radiiKm)
                ButtonSegment(value: r, label: Text('$r km')),
            ],
            selected: {_selected},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _selected = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            '${l10n.settingsOfflineMapEstimateLabel}: '
            '${config.tiles.length} tiles · ~$mb MB',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (tooLarge) ...[
            const SizedBox(height: 8),
            Text(
              l10n.settingsOfflineMapTooLarge,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed:
              tooLarge ? null : () => Navigator.of(context).pop(_buildConfig()),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress dialog
// ---------------------------------------------------------------------------

class _DownloadProgressDialog extends StatefulWidget {
  const _DownloadProgressDialog({required this.config});

  final _DownloadConfig config;

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  bool _cancelled = false;
  int _done = 0;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    // Kick off after first frame so the dialog is visible immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final tiles = widget.config.tiles;
    var i = 0;
    while (i < tiles.length && !_cancelled) {
      final batchEnd = math.min(i + _concurrency, tiles.length);
      final batchStart = DateTime.now();
      final results = await Future.wait([
        for (var k = i; k < batchEnd; k++) _fetch(tiles[k]),
      ]);
      if (_cancelled) break;
      for (final r in results) {
        _done += 1;
        _bytes += r;
        if (_bytes > _maxBundleBytes) {
          _cancelled = true;
          break;
        }
      }
      if (mounted) setState(() {});
      // Pace bursts: aim for ≤ ~8 req/s peak (4 in flight per 500 ms).
      final elapsed = DateTime.now().difference(batchStart).inMilliseconds;
      if (elapsed < 500 && !_cancelled) {
        await Future<void>.delayed(Duration(milliseconds: 500 - elapsed));
      }
      i = batchEnd;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    final l10n = AppLocalizations.of(context)!;
    final mb = (_bytes / (1024 * 1024)).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.settingsOfflineMapDone}: $_done tiles · ${mb}MB'),
      ),
    );
  }

  Future<int> _fetch(({int z, int x, int y}) t) async {
    if (_cancelled) return 0;
    return prefetchOsmTile(_tileUrl(t.z, t.x, t.y));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = widget.config.tiles.length;
    final progress = total == 0 ? 0.0 : _done / total;
    final mb = (_bytes / (1024 * 1024)).toStringAsFixed(1);
    return AlertDialog(
      title: Text(l10n.settingsOfflineMapInProgress),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Text('$_done / $total tiles · ${mb}MB'),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _cancelled ? null : () => setState(() => _cancelled = true),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
