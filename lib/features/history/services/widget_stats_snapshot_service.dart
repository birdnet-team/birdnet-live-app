import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../../explore/explore_providers.dart';
import '../../live/live_providers.dart';
import '../../live/live_session.dart';

const MethodChannel _widgetStatsChannel = MethodChannel(
  'com.birdnet/widget_stats',
);

class WidgetStatsSnapshotService {
  const WidgetStatsSnapshotService._();

  static Future<void> sync(WidgetRef ref) async {
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final sessions = await repo.listAll();
      final taxonomy = await ref.read(taxonomyServiceProvider.future);
      final prefs = ref.read(sharedPreferencesProvider);

      final allDetections = <DetectionRecord>[];
      for (final session in sessions) {
        allDetections.addAll(session.detections);
      }

      allDetections.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final limited = allDetections.take(240).toList();

      final imagesDir = await _ensureImageDir();
      final encodedDetections = <Map<String, dynamic>>[];
      for (final detection in limited) {
        final imagePath = await _resolveImagePath(
          taxonomy: taxonomy,
          scientificName: detection.scientificName,
          imagesDir: imagesDir,
        );

        encodedDetections.add({
          'scientificName': detection.scientificName,
          'commonName': detection.commonName,
          'confidence': detection.confidence,
          'timestampMs': detection.timestamp.millisecondsSinceEpoch,
          if (imagePath != null) 'imagePath': imagePath,
        });
      }

      final payload = <String, dynamic>{
        'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'detections': encodedDetections,
      };

      await prefs.setString(PrefKeys.widgetStatsSnapshot, json.encode(payload));

      try {
        await _widgetStatsChannel.invokeMethod<void>('refreshDetectionStatsWidget');
      } catch (_) {
        // Non-Android platforms and older builds may not provide the channel.
      }
    } catch (_) {
      // Best-effort sync; widget keeps rendering last known snapshot.
    }
  }

  static Future<Directory> _ensureImageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'widget_species_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static Future<String?> _resolveImagePath({
    required TaxonomyService taxonomy,
    required String scientificName,
    required Directory imagesDir,
  }) async {
    final assetPath = taxonomy.assetImagePath(scientificName);
    if (assetPath.isEmpty) return null;

    final filename = p.basename(assetPath);
    final outFile = File(p.join(imagesDir.path, filename));
    if (await outFile.exists()) {
      return outFile.path;
    }

    try {
      final bytes = await rootBundle.load(assetPath);
      await outFile.writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );
      return outFile.path;
    } catch (_) {
      return null;
    }
  }
}
