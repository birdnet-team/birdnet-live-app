// =============================================================================
// Session Map Screen
// =============================================================================
//
// Displays the recording location on an interactive OpenStreetMap-based map.
//
// Privacy: Before loading map tiles the user must consent to connecting to
// the OpenStreetMap tile servers (GDPR compliance).  The consent flag is
// persisted in SharedPreferences so the dialog appears only once.
//
// Offline: If tiles cannot be loaded (no internet), flutter_map shows blank
// tiles.  The marker (recording location) is always visible because it is
// drawn locally.  The `CachedNetworkImageProvider` caches previously loaded
// tiles to disk so areas the user has viewed before remain available offline.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';

/// Map screen showing the recording location with a pin marker.
///
/// Requires user consent before fetching OpenStreetMap tiles.  Consent is
/// stored via [PrefKeys.mapTileConsent] and is valid across sessions.
class SessionMapScreen extends ConsumerStatefulWidget {
  const SessionMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
  });

  final double latitude;
  final double longitude;
  final String? locationName;

  @override
  ConsumerState<SessionMapScreen> createState() => _SessionMapScreenState();
}

class _SessionMapScreenState extends ConsumerState<SessionMapScreen> {
  bool? _hasConsent;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  void _checkConsent() {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _hasConsent = prefs.getBool(PrefKeys.mapTileConsent) ?? false;
    });
  }

  Future<void> _requestConsent() async {
    final l10n = AppLocalizations.of(context)!;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mapTileConsentTitle),
        content: Text(l10n.mapTileConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.mapTileConsentCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.mapTileConsentAllow),
          ),
        ],
      ),
    );
    if (agreed == true) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(PrefKeys.mapTileConsent, true);
      setState(() => _hasConsent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final center = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName ?? l10n.recordingLocation),
      ),
      body: _hasConsent == true
          ? _buildMap(center, theme)
          : _buildConsentPlaceholder(center, theme),
    );
  }

  Widget _buildMap(LatLng center, ThemeData theme) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'birdnet_live',
          tileProvider: _CachingTileProvider(),
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: Icon(
                Icons.location_on,
                color: theme.colorScheme.error,
                size: 40,
              ),
            ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConsentPlaceholder(LatLng center, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              '${widget.latitude.toStringAsFixed(4)}, '
              '${widget.longitude.toStringAsFixed(4)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _requestConsent,
              icon: const Icon(Icons.map),
              label: Text(l10n.mapLoadButton),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mapLoadHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile provider that uses [CachedNetworkImageProvider] for disk caching.
///
/// Previously viewed map tiles are available offline because the image cache
/// persists to disk (via the `cached_network_image` package which is already
/// a project dependency for species thumbnails).
class _CachingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
    );
  }
}
