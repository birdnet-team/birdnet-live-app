// =============================================================================
// Upload Providers — destination list, keychain, probe, device identity
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/uuid.dart';
import '../explore/explore_providers.dart';
import '../history/export_metadata_helper.dart';
import '../history/services/share_export_config.dart';
import '../history/session_export.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import 'connectivity.dart';
import 'join_link.dart';
import 'secret_store.dart';
import 'upload_destination.dart';
import 'upload_destination_store.dart';
import 'upload_queue_store.dart';
import 'upload_service.dart';
import 'webdav_client.dart';
import 'webdav_probe.dart';

/// Keychain-backed credential store. Overridden with [InMemorySecretStore]
/// in tests.
final secretStoreProvider = Provider<SecretStore>(
  (ref) => PlatformSecretStore(),
);

final uploadDestinationStoreProvider = Provider<UploadDestinationStore>(
  (ref) => UploadDestinationStore(),
);

final webDavProbeProvider = Provider<WebDavProbe>((ref) => WebDavProbe());

/// Random, stable identity of this install toward upload destinations. Used
/// as the contributor folder name; carries no personal data.
final uploadDeviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(PrefKeys.uploadDeviceId);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = generateUuidV4();
  prefs.setString(PrefKeys.uploadDeviceId, id);
  return id;
});

/// The record a device writes into `_joined/` when it joins a destination.
Map<String, Object?> joinRegistrationRecord({
  required String deviceId,
  required String appVersion,
}) {
  return {
    'deviceId': deviceId,
    'joinedAt': DateTime.now().toUtc().toIso8601String(),
    'app': 'BirdNET Live',
    'appVersion': appVersion,
    'platform': Platform.operatingSystem,
  };
}

/// The configured destinations, loaded from disk once and kept in memory.
class UploadDestinationsNotifier
    extends AsyncNotifier<List<UploadDestination>> {
  @override
  Future<List<UploadDestination>> build() =>
      ref.read(uploadDestinationStoreProvider).load();

  /// Adds a destination the probe accepted. The secret is written to the
  /// keychain first; if the list cannot be saved it is removed again so no
  /// orphaned credential stays behind.
  Future<UploadDestination> add({
    required JoinRequest request,
    required ProbeResult result,
    required String name,
    bool? wifiOnly,
    bool autoUploadAru = false,
  }) async {
    final destination = UploadDestination(
      id: generateUuidV4(),
      name: name.trim(),
      url: result.resolvedUrl,
      username: request.username,
      wifiOnly: wifiOnly ?? request.wifiOnly ?? true,
      autoUploadAru: autoUploadAru,
      flatLayout: result.flatLayout,
      canReadRemote: result.warnings.contains(ProbeWarning.canReadRemote),
      shareWithoutPassword: result.warnings.contains(
        ProbeWarning.shareWithoutPassword,
      ),
      createdAt: DateTime.now(),
    );
    final secrets = ref.read(secretStoreProvider);
    await secrets.write(destination.secretKey, request.secret);
    try {
      await _persist([...await future, destination]);
    } catch (_) {
      await secrets.delete(destination.secretKey);
      rethrow;
    }
    return destination;
  }

  /// Replaces the destination with the same id.
  Future<void> replace(UploadDestination destination) async {
    final current = await future;
    await _persist([
      for (final d in current) d.id == destination.id ? destination : d,
    ]);
  }

  /// Removes the destination and its secret.
  Future<void> remove(String id) async {
    final current = await future;
    final target = current.where((d) => d.id == id).firstOrNull;
    if (target == null) return;
    await ref.read(uploadServiceProvider).cancelForDestination(id);
    await _persist([
      for (final d in current)
        if (d.id != id) d,
    ]);
    try {
      await ref.read(secretStoreProvider).delete(target.secretKey);
    } on SecretStoreException {
      // The list entry is gone; a stale keychain item is harmless.
    }
  }

  /// The secret for [destination], or null when the keychain lost it.
  Future<String?> secretFor(UploadDestination destination) =>
      ref.read(secretStoreProvider).read(destination.secretKey);

  Future<void> _persist(List<UploadDestination> list) async {
    await ref.read(uploadDestinationStoreProvider).save(list);
    state = AsyncData(list);
  }
}

final uploadDestinationsProvider =
    AsyncNotifierProvider<UploadDestinationsNotifier, List<UploadDestination>>(
      UploadDestinationsNotifier.new,
    );

final connectivityProvider = Provider<Connectivity>(
  (ref) => PlatformConnectivity(),
);

final uploadQueueStoreProvider = Provider<UploadQueueStore>(
  (ref) => UploadQueueStore(),
);

/// The export configuration uploads use when nobody chose one for the job
/// (ARU auto-upload): the saved Export & Sync preferences.
ShareExportConfig defaultUploadConfig(Ref ref) => ShareExportConfig(
  formats: ref.read(exportSelectionProvider),
  includeAudio: ref.read(includeAudioProvider),
  shareAudioAsWav: ref.read(shareAudioAsWavProvider),
  includeHtmlReport: ref.read(exportHtmlReportProvider),
  includeAppMetadata: ref.read(includeAppMetadataProvider),
);

/// The queue engine. Lives for the whole app so a run started from one
/// screen finishes after that screen is gone.
final uploadServiceProvider = Provider<UploadService>((ref) {
  Future<Map<String, dynamic>> metadataFor(LiveSession session) =>
      buildSessionExportMetadata(
        session,
        speciesLocale: ref.read(effectiveSpeciesLocaleProvider),
      );

  final service = UploadService(
    store: ref.watch(uploadQueueStoreProvider),
    client: WebDavClient(),
    connectivity: ref.watch(connectivityProvider),
    deviceId: () => ref.read(uploadDeviceIdProvider),
    appVersion: () async => (await PackageInfo.fromPlatform()).version,
    loadSession: (id) => ref.read(sessionRepositoryProvider).load(id),
    findDestination: (id) async {
      final list = await ref.read(uploadDestinationsProvider.future);
      for (final d in list) {
        if (d.id == id) return d;
      }
      return null;
    },
    secretFor: (d) =>
        ref.read(uploadDestinationsProvider.notifier).secretFor(d),
    buildExport: (session, config) async {
      final taxonomy = ref.read(taxonomyServiceProvider).value;
      final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
      // Same legacy-clip fallback as Session Review's share (see
      // session_review_screen.dart `_share`).
      final clips = session.detections.where(
        (d) => d.audioClipPath != null && d.audioClipPath!.isNotEmpty,
      );
      final hasOnlyLegacyClips =
          clips.isNotEmpty && clips.every((d) => d.clipTimestamp == null);
      final clipContextOverride =
          hasOnlyLegacyClips && session.settings.clipContextSeconds == 0
          ? ref.read(surveyClipContextProvider)
          : null;
      return buildSessionExport(
        session,
        formats: config.formats,
        includeAudio: config.includeAudio,
        shareAudioAsWav: config.shareAudioAsWav,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        clipContextSecondsOverride: clipContextOverride,
        metadata: await metadataFor(session),
        useAbsoluteSurveyTime:
            ref.read(timestampDisplayModeProvider) == 'absolute',
        includeHtmlReport: config.includeHtmlReport,
        includeAppMetadata: config.includeAppMetadata,
      );
    },
    buildJson: (session) async => buildJsonExport(
      session,
      metadata: await metadataFor(session),
      taxonomy: ref.read(taxonomyServiceProvider).value,
      speciesLocale: ref.read(effectiveSpeciesLocaleProvider),
    ),
    onDestinationUploaded: (destination, at) async {
      final notifier = ref.read(uploadDestinationsProvider.notifier);
      final list = await ref.read(uploadDestinationsProvider.future);
      for (final d in list) {
        if (d.id == destination.id) {
          await notifier.replace(d.copyWith(lastUploadAt: at));
          return;
        }
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Queues a finalized ARU session for every destination whose
/// "Upload ARU sessions automatically" switch is on. Aggregate deployments
/// that are split into per-cycle sessions are skipped: their cycles are
/// uploaded instead, and the aggregate is discarded on completion.
Future<void> autoEnqueueAruSession(Ref ref, LiveSession session) async {
  if (session.type != SessionType.aru || session.endTime == null) return;
  final perCycle = session.aruMetadata?.eachCycleIsSession ?? false;
  final isCycle = session.id.contains('_cycle_');
  if (perCycle && !isCycle) return;
  final destinations = await ref.read(uploadDestinationsProvider.future);
  final targets = destinations.where((d) => d.autoUploadAru).toList();
  if (targets.isEmpty) return;
  final service = ref.read(uploadServiceProvider);
  final config = defaultUploadConfig(ref);
  for (final destination in targets) {
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
  }
}
