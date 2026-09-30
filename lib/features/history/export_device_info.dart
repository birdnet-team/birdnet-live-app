import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads only public model and OS details. The native channel never requests
/// device IDs, user-assigned names, or network data.
Future<({String device, String os})> exportDeviceInfo() async {
  const channel = MethodChannel('com.birdnet/device_description');
  final platform = defaultTargetPlatform;

  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    try {
      final details = await channel.invokeMapMethod<String, String>('getInfo');
      if (details != null) {
        return formatExportDeviceInfo(
          platform:
              details['os'] ??
              (platform == TargetPlatform.iOS ? 'iOS' : 'Android'),
          model: details['model'],
          brand: details['brand'],
          version: details['version'],
        );
      }
    } catch (_) {
      // A missing channel must not prevent an export.
    }
  }

  if (platform == TargetPlatform.windows) {
    final osVersion = Platform.operatingSystemVersion;
    final windowsVersion = RegExp(
      r'Windows (\d+)',
    ).firstMatch(osVersion)?.group(1);
    return formatExportDeviceInfo(platform: 'Windows', version: windowsVersion);
  }
  if (platform == TargetPlatform.macOS) {
    final version = RegExp(
      r'Version (\d+(?:\.\d+)*)',
      caseSensitive: false,
    ).firstMatch(Platform.operatingSystemVersion)?.group(1);
    return formatExportDeviceInfo(platform: 'macOS', version: version);
  }
  return formatExportDeviceInfo(
    platform: switch (platform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.macOS => 'macOS',
    },
  );
}

/// Formats only broad, user-recognizable device and OS details.
({String device, String os}) formatExportDeviceInfo({
  required String platform,
  String? model,
  String? brand,
  String? version,
}) {
  final candidate = model?.trim() ?? '';
  final hasReadableModel =
      candidate.isNotEmpty &&
      !RegExp(
        r'^(unknown|generic|sdk|emulator)',
        caseSensitive: false,
      ).hasMatch(candidate) &&
      !RegExp(r'[_/]|^[A-Z]{1,5}[-\d][A-Z0-9,-]*$').hasMatch(candidate) &&
      !RegExp(r'^[A-Za-z]+\d+,\d+$').hasMatch(candidate);
  final safeBrand = brand?.trim();
  final fallback = switch (platform) {
    'Android' =>
      safeBrand != null &&
              RegExp(r'^[A-Za-z][A-Za-z .-]{1,24}$').hasMatch(safeBrand)
          ? '$safeBrand device'
          : 'Android device',
    'iOS' || 'iPadOS' => 'iPhone or iPad',
    'macOS' => 'Mac',
    'Windows' => 'Windows PC',
    'Linux' => 'Linux computer',
    _ => '$platform device',
  };
  final device = hasReadableModel ? candidate : fallback;
  final os = [
    platform,
    if (version != null && version.trim().isNotEmpty) version.trim(),
  ].join(' ');
  return (device: device, os: os);
}
