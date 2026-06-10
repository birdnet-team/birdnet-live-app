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
// If tiles cannot be loaded, the map shows blank tiles instead of surfacing
// network image exceptions. The location marker is always visible because it
// is drawn locally.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import '../../shared/services/link_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/open_street_map_tile_layer.dart';

/// Map screen showing the recording location with a pin marker.
///
/// Requires user consent before fetching OpenStreetMap tiles. Consent is
/// stored via [PrefKeys.privacyAllowMap] (revocable from Settings → Privacy).
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
      _hasConsent = prefs.getBool(PrefKeys.privacyAllowMap) ?? false;
    });
  }

  Future<void> _requestConsent() async {
    final l10n = AppLocalizations.of(context)!;
    final agreed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
      await ref.read(privacyAllowMapProvider.notifier).set(true);
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
        actions: [
          if (Platform.isIOS)
            IconButton(
              icon: const Icon(AppIcons.openInNew),
              tooltip: l10n.openInAppleMaps,
              onPressed: () => openExternalUrl(
                context,
                'https://maps.apple.com/?q=${widget.latitude},${widget.longitude}',
              ),
            ),
        ],
      ),
      body:
          _hasConsent == true
              ? _buildMap(center, theme)
              : _buildConsentPlaceholder(center, theme),
    );
  }

  Widget _buildMap(LatLng center, ThemeData theme) {
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        buildOpenStreetMapTileLayer(),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: Icon(
                AppIcons.locationOnFilled,
                color: theme.colorScheme.error,
                size: 40,
              ),
            ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap (ODbL)', onTap: () {}),
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
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
            Icon(
              AppIcons.map,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.latitude.toStringAsFixed(4)}, '
              '${widget.longitude.toStringAsFixed(4)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _requestConsent,
              icon: const Icon(AppIcons.map),
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
