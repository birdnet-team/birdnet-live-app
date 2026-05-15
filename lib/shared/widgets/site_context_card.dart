// =============================================================================
// SiteContextCard
// =============================================================================
//
// Compact, network-aware card showing the two pieces of *site context*
// the app collects from external services for any GPS-located session:
//
//   • Place name  (Nominatim reverse geocoding)
//   • Weather     (Open-Meteo)
//
// Used by the survey and point-count setup wizards' "Ready" step so the
// user can see *what will be captured* before they tap Start. Both calls
// hit the persistent caches (reverse-geocode no-TTL, weather 6 h) which
// means visiting the same site twice never re-hits the network, and
// session-end captures will be cache-fast too.
//
// Consent handling
// ----------------
// Both services are gated behind privacy toggles in Settings → Privacy.
// If a toggle is off and there is no cached value to fall back on, the
// card shows an inline "Tap to allow X" row instead of silently hiding
// the service. Tapping the row flips the toggle on, fires the lookup,
// and replaces itself with the result. This is the same opportunistic
// consent prompt used elsewhere in the wizard (e.g. for GPS).
//
// All calls are best-effort: failures (network unreachable, service down,
// consent still off) collapse the corresponding row. If both rows would
// be empty, the card renders nothing (returns SizedBox.shrink).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../l10n/app_localizations.dart';
import '../models/weather_snapshot.dart';
import '../providers/settings_providers.dart';
import '../services/weather_service.dart';
import '../utils/weather_format.dart';

class SiteContextCard extends ConsumerStatefulWidget {
  const SiteContextCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.observedAt,
  });

  final double latitude;
  final double longitude;

  /// Timestamp the weather should describe. Defaults to "now" when null,
  /// which is the right choice for the setup wizard (the user is about
  /// to start recording).
  final DateTime? observedAt;

  @override
  ConsumerState<SiteContextCard> createState() => _SiteContextCardState();
}

class _SiteContextCardState extends ConsumerState<SiteContextCard> {
  String? _locationName;
  WeatherSnapshot? _weather;
  bool _loading = true;
  // Per-service "we tried while consent was on, but the lookup did not
  // produce a result" flags. Used to decide whether to show the offline
  // note. Reset whenever we (re)attempt a lookup so a successful retry
  // clears the warning.
  bool _locationFailed = false;
  bool _weatherFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SiteContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when the user changes the location (manual entry,
    // re-tap GPS, etc.). Cache hits make this cheap.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _locationName = null;
        _weather = null;
        _loading = true;
      });
      _resolve();
    }
  }

  Future<void> _resolveLocation() async {
    // Only attempt if the user has granted consent; otherwise the row
    // shows the consent prompt instead of an offline note.
    if (!ref.read(privacyAllowReverseGeocodingProvider)) return;
    try {
      final name = await reverseGeocode(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (!mounted) return;
      setState(() {
        _locationName = name;
        _locationFailed = name == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationFailed = true);
    }
  }

  Future<void> _resolveWeather() async {
    if (!ref.read(privacyAllowWeatherProvider)) return;
    try {
      final svc = ref.read(weatherServiceProvider);
      final w = await svc.fetch(
        latitude: widget.latitude,
        longitude: widget.longitude,
        observedAt: widget.observedAt ?? DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _weather = w;
        _weatherFailed = w == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _weatherFailed = true);
    }
  }

  Future<void> _resolve() async {
    await Future.wait([_resolveLocation(), _resolveWeather()]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _enableLocationConsent() async {
    await ref.read(privacyAllowReverseGeocodingProvider.notifier).set(true);
    await _resolveLocation();
  }

  Future<void> _enableWeatherConsent() async {
    await ref.read(privacyAllowWeatherProvider.notifier).set(true);
    await _resolveWeather();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final allowReverseGeo = ref.watch(privacyAllowReverseGeocodingProvider);
    final allowWeather = ref.watch(privacyAllowWeatherProvider);

    if (_loading && _locationName == null && _weather == null) {
      // Single-line placeholder while both lookups are in flight —
      // avoids a layout pop when results arrive.
      return SizedBox(
        height: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];

    // Place name row.
    if (_locationName != null) {
      rows.add(
        _ContextRow(
          icon: Icons.location_on_outlined,
          child: Text(
            _locationName!,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else if (!allowReverseGeo) {
      rows.add(
        _ConsentPromptRow(
          icon: Icons.location_on_outlined,
          label: l10n.settingsPrivacyAllowReverseGeocoding,
          onTap: _enableLocationConsent,
        ),
      );
    }

    // Weather row.
    if (_weather != null) {
      final cond = weatherConditionFromCode(_weather!.weatherCode);
      // Show temperature + wind side by side: with the icon prefix the
      // line stays compact (e.g. "☀️ 18.4 °C · 3.2 m/s SW")
      // and gives users the second most useful field for assessing how
      // much wind noise is in the recording at a glance.
      final parts = <String>[];
      if (_weather!.temperatureC != null) {
        parts.add(formatTemperature(_weather!.temperatureC));
      }
      if (_weather!.windSpeedMs != null) {
        parts.add(
          formatWind(_weather!.windSpeedMs, _weather!.windDirectionDeg),
        );
      }
      if (parts.isNotEmpty) {
        rows.add(
          _ContextRow(
            icon: weatherConditionIcon(cond),
            child: Text(
              parts.join(' · '),
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } else if (!allowWeather) {
      rows.add(
        _ConsentPromptRow(
          icon: Icons.cloud_outlined,
          label: l10n.settingsPrivacyAllowWeather,
          onTap: _enableWeatherConsent,
        ),
      );
    }

    // If at least one consented lookup failed, append a subtle offline
    // note. Reverse-geo and weather both retry on session-review open,
    // so the data isn't lost — we just want users to know.
    final showOfflineNote = _locationFailed || _weatherFailed;
    if (showOfflineNote) {
      rows.add(
        Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.siteContextOfflineNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
      ],
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _ConsentPromptRow extends StatelessWidget {
  const _ConsentPromptRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: primary,
                  decoration: TextDecoration.underline,
                  decorationColor: primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
