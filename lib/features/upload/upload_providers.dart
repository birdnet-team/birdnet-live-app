// =============================================================================
// Upload Providers — destination list, keychain, probe, device identity
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

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
import 'upload_background.dart';
import 'upload_destination.dart';
import 'upload_destination_store.dart';
import 'upload_naming.dart';
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

/// Random, stable identity of this install toward upload destinations.
/// Recorded in the registration file; its first eight hex digits are the
/// device code that names this device's folder at every destination.
final uploadDeviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(PrefKeys.uploadDeviceId);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = generateUuidV4();
  prefs.setString(PrefKeys.uploadDeviceId, id);
  return id;
});

/// Optional participant identifier (name, email, participant id) the user
/// entered. Goes into the registration record and every upload's metadata,
/// never into a path.
final uploadParticipantProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      return StringSettingNotifier(
        ref.watch(sharedPreferencesProvider),
        PrefKeys.uploadParticipant,
        '',
      );
    });

/// The folder this device's uploads land in at every destination.
final uploadDeviceCodeProvider = Provider<String>((ref) {
  return uploadDeviceCode(ref.watch(uploadDeviceIdProvider));
});

/// The record a device writes into `.birdnet-live/<deviceCode>.json` when it
/// joins a destination.
Map<String, Object?> joinRegistrationRecord({
  required String deviceId,
  required String appVersion,
  String participant = '',
}) {
  return {
    'deviceId': deviceId,
    'deviceCode': uploadDeviceCode(deviceId),
    if (participant.isNotEmpty) 'participant': participant,
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
/// (automatic uploads): the saved Export & Sync preferences.
ShareExportConfig defaultUploadConfig(
  T Function<T>(ProviderListenable<T> provider) read,
) => ShareExportConfig(
  formats: read(exportSelectionProvider),
  includeAudio: read(includeAudioProvider),
  shareAudioAsWav: read(shareAudioAsWavProvider),
  includeHtmlReport: read(exportHtmlReportProvider),
  includeAppMetadata: read(includeAppMetadataProvider),
);

/// The queue engine. Lives for the whole app so a run started from one
/// screen finishes after that screen is gone.
final uploadServiceProvider = Provider<UploadService>((ref) {
  // Uploads carry who sent them in the record's metadata: the device code
  // (the folder name) and the participant identifier, if one was entered.
  Future<Map<String, dynamic>> metadataFor(LiveSession session) async {
    final meta = await buildSessionExportMetadata(
      session,
      speciesLocale: ref.read(effectiveSpeciesLocaleProvider),
    );
    final participant = ref.read(uploadParticipantProvider);
    return {
      ...meta,
      'deviceCode': ref.read(uploadDeviceCodeProvider),
      if (participant.isNotEmpty) 'participant': participant,
    };
  }

  final service = UploadService(
    store: ref.watch(uploadQueueStoreProvider),
    client: WebDavClient(),
    connectivity: ref.watch(connectivityProvider),
    deviceCode: () => ref.read(uploadDeviceCodeProvider),
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
        alwaysZip: true,
      );
    },
    onPendingChanged: UploadWorkScheduler.onPendingChanged,
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

/// Queues a finalized session for every destination that takes it without
/// asking: "Upload all sessions automatically" for any session, plus "Upload
/// ARU sessions automatically" for ARU sessions. Aggregate deployments that
/// are split into per-cycle sessions are skipped: their cycles are uploaded
/// instead, and the aggregate is discarded on completion.
///
/// Runs inside session finalization, so a failure here is logged and never
/// reaches the caller: the session is saved and can still be sent by hand.
/// [read] is the `read` of a Ref or a ProviderContainer; session screens pass
/// their container so the call survives the route going away.
Future<void> autoEnqueueSession(
  T Function<T>(ProviderListenable<T> provider) read,
  LiveSession session,
) async {
  if (session.endTime == null) return;
  final isAru = session.type == SessionType.aru;
  final perCycle = session.aruMetadata?.eachCycleIsSession ?? false;
  final isCycle = session.id.contains('_cycle_');
  if (isAru && perCycle && !isCycle) return;
  try {
    final destinations = await read(uploadDestinationsProvider.future);
    final targets = destinations
        .where((d) => d.autoUploadAll || (isAru && d.autoUploadAru))
        .toList();
    if (targets.isEmpty) return;
    final service = read(uploadServiceProvider);
    final config = defaultUploadConfig(read);
    for (final destination in targets) {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
    }
  } catch (error, stack) {
    debugPrint('autoEnqueueSession failed: $error\n$stack');
  }
}

/// Queues every session in [sessions] for each destination ticked in
/// [config] (the Share dialog's "Send to" group). Returns the number of
/// sessions queued; zero when no destination was ticked.
Future<int> enqueueUploadsFor(
  WidgetRef ref,
  Iterable<LiveSession> sessions,
  ShareExportConfig config,
) async {
  if (config.uploadDestinationIds.isEmpty) return 0;
  final destinations = await ref.read(uploadDestinationsProvider.future);
  final targets = [
    for (final d in destinations)
      if (config.uploadDestinationIds.contains(d.id)) d,
  ];
  if (targets.isEmpty) return 0;
  final service = ref.read(uploadServiceProvider);
  var count = 0;
  for (final session in sessions) {
    for (final destination in targets) {
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
    }
    count++;
  }
  return count;
}
