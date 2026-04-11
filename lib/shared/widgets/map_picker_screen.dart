// =============================================================================
// Map Picker Screen — Shared full-screen map for picking a location
// =============================================================================
//
// Reusable widget used by both file analysis and point count setup to let the
// user tap on an OpenStreetMap map to pick a geographic coordinate.  Respects
// the map tile consent preference — a consent dialog is shown before loading
// any external tiles.
//
// Returns the selected [LatLng] via [Navigator.pop].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_providers.dart';

/// Full-screen map for picking a location by tapping.
///
/// Uses OpenStreetMap tiles via [flutter_map].  Respects the map tile consent
/// preference — if the user hasn't consented yet, a placeholder is shown first.
///
/// Pop result: the selected [LatLng], or `null` if cancelled.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, this.initialLat, this.initialLon});

  final double? initialLat;
  final double? initialLon;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  LatLng? _picked;
  bool? _hasConsent;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLon != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLon!);
    }
    _checkConsent();
  }

  void _checkConsent() {
    final prefs = ref.read(sharedPreferencesProvider);
    _hasConsent = prefs.getBool(PrefKeys.mapTileConsent) ?? false;
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
    final center = _picked ?? const LatLng(48.0, 10.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapPickerTitle),
        actions: [
          if (_picked != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: Text(l10n.mapPickerConfirm),
            ),
        ],
      ),
      body: _hasConsent == true
          ? _buildMap(center, theme)
          : _buildConsentPlaceholder(theme, l10n),
    );
  }

  Widget _buildMap(LatLng center, ThemeData theme) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: _picked != null ? 10 : 3,
        onTap: (_, point) => setState(() => _picked = point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'birdnet_live',
        ),
        if (_picked != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _picked!,
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

  Widget _buildConsentPlaceholder(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
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
