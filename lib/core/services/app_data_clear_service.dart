// =============================================================================
// App Data Clear Service — Privacy-focused local data wipe
// =============================================================================
//
// Coordinates the destructive "Clear All Data" action from Settings. The app
// stores user data across a few small local stores: session JSON, recordings,
// user species lists, temporary review/share caches, SharedPreferences, and the
// dedicated OpenStreetMap tile cache. This service keeps that storage knowledge
// out of UI code and gives tests injectable directory/cache providers.
// =============================================================================

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/upload/secret_store.dart';
import '../../features/upload/upload_destination_store.dart';
import '../../features/upload/upload_queue_store.dart';
import '../../shared/widgets/open_street_map_tile_layer.dart';

typedef DirectoryProvider = Future<Directory> Function();
typedef SharedPreferencesProvider = Future<SharedPreferences> Function();
typedef CacheClearer = Future<void> Function();

/// Clears all user-owned data BirdNET Live stores locally.
class AppDataClearService {
  /// Creates a clear service. Optional providers are for tests.
  const AppDataClearService({
    DirectoryProvider? documentsDirectoryProvider,
    DirectoryProvider? temporaryDirectoryProvider,
    SharedPreferencesProvider? sharedPreferencesProvider,
    CacheClearer? mapTileCacheClearer,
    CacheClearer? uploadDestinationsClearer,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _sharedPreferencesProvider =
           sharedPreferencesProvider ?? SharedPreferences.getInstance,
       _mapTileCacheClearer =
           mapTileCacheClearer ?? clearOpenStreetMapTileCache,
       _uploadDestinationsClearer = uploadDestinationsClearer;

  final DirectoryProvider _documentsDirectoryProvider;
  final DirectoryProvider _temporaryDirectoryProvider;
  final SharedPreferencesProvider _sharedPreferencesProvider;
  final CacheClearer _mapTileCacheClearer;

  /// Null means: clear the destination list in the documents directory and
  /// every secret it names from the platform keychain.
  final CacheClearer? _uploadDestinationsClearer;

  /// Removes every upload destination in [documentsDir] together with its
  /// keychain secret.
  static Future<void> clearUploadDestinations(Directory documentsDir) async {
    final store = UploadDestinationStore(
      documentsDirectory: () async => documentsDir,
    );
    final secrets = PlatformSecretStore();
    for (final destination in await store.load()) {
      try {
        await secrets.delete(destination.secretKey);
      } on SecretStoreException {
        // The list goes regardless; a stale keychain item is harmless.
      }
    }
    await store.deleteAll();
    await UploadQueueStore(documentsDirectory: () async => documentsDir)
        .deleteAll();
  }

  /// Deletes local user data and cached third-party service results.
  ///
  /// The wipe is best-effort across stores: every known store is attempted even
  /// if one fails, then [AppDataClearException] is thrown if anything could not
  /// be cleared.
  Future<void> clearAllData() async {
    final failures = <Object>[];

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures.add(error);
      }
    }

    final documentsDir = await _documentsDirectoryProvider();
    final temporaryDir = await _temporaryDirectoryProvider();

    for (final name in _documentDataDirectories) {
      await attempt(
        () => _deleteDirectoryIfExists(p.join(documentsDir.path, name)),
      );
    }

    for (final name in _temporaryDataDirectories) {
      await attempt(
        () => _deleteDirectoryIfExists(p.join(temporaryDir.path, name)),
      );
    }

    await attempt(_mapTileCacheClearer);
    await attempt(
      _uploadDestinationsClearer ?? () => clearUploadDestinations(documentsDir),
    );
    await attempt(() async {
      final prefs = await _sharedPreferencesProvider();
      await prefs.clear();
    });

    if (failures.isNotEmpty) {
      throw AppDataClearException(failures.length);
    }
  }

  static const List<String> _documentDataDirectories = [
    'sessions',
    'recordings',
    'species_lists',
  ];

  static const List<String> _temporaryDataDirectories = [
    'birdnet_norm_cache',
    'birdnet_spec_wav',
    'shared_clips',
  ];

  static Future<void> _deleteDirectoryIfExists(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

/// Thrown when at least one local store could not be cleared.
class AppDataClearException implements Exception {
  /// Creates a failure with the number of stores that could not be cleared.
  const AppDataClearException(this.failureCount);

  /// Number of failed clear operations.
  final int failureCount;

  @override
  String toString() => 'AppDataClearException($failureCount failures)';
}
