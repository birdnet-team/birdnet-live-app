// =============================================================================
// Weather Setup Card — setup-time weather consent and preview
// =============================================================================
//
// Compact card used in Point Count and Survey setup. It mirrors the shape of
// the location cards in those screens: one icon, one primary line, optional
// supporting text, and a refresh/action affordance.
//
// Behavior:
//   • Weather privacy gate off: show an inline consent prompt.
//   • Weather privacy gate on + coordinates available: fetch and preview the
//     Open-Meteo snapshot that will be saved with the session.
//   • Weather privacy gate on + no coordinates/result: show a neutral status.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../l10n/app_localizations.dart';
import '../models/weather_snapshot.dart';
import '../providers/settings_providers.dart';
import '../services/weather_service.dart';
import '../utils/weather_format.dart';

class WeatherSetupCard extends ConsumerStatefulWidget {
  const WeatherSetupCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationUnavailableLabel,
  });

  final double? latitude;
  final double? longitude;
  final String locationUnavailableLabel;

  @override
  ConsumerState<WeatherSetupCard> createState() => _WeatherSetupCardState();
}

class _WeatherSetupCardState extends ConsumerState<WeatherSetupCard> {
  WeatherSnapshot? _weather;
  bool _loading = false;
  bool _failed = false;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _resolveIfAllowed();
  }

  @override
  void didUpdateWidget(covariant WeatherSetupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _weather = null;
        _failed = false;
      });
      _resolveIfAllowed();
    }
  }

  Future<void> _enableWeatherConsent() async {
    await ref.read(privacyAllowWeatherProvider.notifier).set(true);
    await _resolveIfAllowed(force: true);
  }

  Future<void> _resolveIfAllowed({bool force = false}) async {
    if (!ref.read(privacyAllowWeatherProvider)) return;
    if (widget.latitude == null || widget.longitude == null) return;
    if (_loading) return;
    if (!force && _weather != null) return;

    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final service = ref.read(weatherServiceProvider);
      final weather = await service.fetch(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        observedAt: DateTime.now(),
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _weather = weather;
        _failed = weather == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final allowWeather = ref.watch(privacyAllowWeatherProvider);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    if (!allowWeather) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _enableWeatherConsent,
          child: ListTile(
            leading: Icon(AppIcons.cloud, color: onSurfaceVariant),
            title: Text(l10n.settingsPrivacyAllowWeather),
            subtitle: Text(l10n.settingsPrivacyAllowWeatherSubtitle),
            trailing: Icon(
              AppIcons.chevronRight,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (widget.latitude == null || widget.longitude == null) {
      return Card(
        child: ListTile(
          leading: Icon(AppIcons.cloudOff, color: onSurfaceVariant),
          title: Text(l10n.sessionWeatherSection),
          subtitle: Text(widget.locationUnavailableLabel),
        ),
      );
    }

    if (_loading) {
      return Card(
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          title: Text(l10n.sessionWeatherSection),
          subtitle: Text(l10n.settingsPrivacyAllowWeatherSubtitle),
        ),
      );
    }

    final weather = _weather;
    if (weather != null) {
      final condition = weatherConditionFromCode(weather.weatherCode);
      return Card(
        child: ListTile(
          leading: Icon(
            weatherConditionIcon(condition),
            color: onSurfaceVariant,
          ),
          title: Text(
            formatWeatherCompactStats(weather, l10n: l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            onPressed: () => _resolveIfAllowed(force: true),
            icon: const Icon(AppIcons.refresh),
            tooltip: l10n.pointCountLocationRefresh,
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(AppIcons.cloudOff, color: onSurfaceVariant),
        title: Text(l10n.sessionWeatherSection),
        subtitle: Text(
          _failed
              ? l10n.siteContextOfflineNote
              : widget.locationUnavailableLabel,
        ),
        trailing: IconButton(
          onPressed: () => _resolveIfAllowed(force: true),
          icon: const Icon(AppIcons.refresh),
          tooltip: l10n.pointCountLocationRefresh,
        ),
      ),
    );
  }
}
