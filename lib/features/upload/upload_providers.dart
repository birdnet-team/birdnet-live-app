// =============================================================================
// Upload Providers — destination list, keychain, probe, device identity
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/utils/uuid.dart';
import 'join_link.dart';
import 'secret_store.dart';
import 'upload_destination.dart';
import 'upload_destination_store.dart';
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
