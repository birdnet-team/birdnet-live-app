// =============================================================================
// Secret Store — destination credentials in the platform keychain
// =============================================================================
//
// Upload destination secrets never touch SharedPreferences or the JSON
// destination list. They go through the `com.birdnet/secure_store` channel to
// the Android Keystore (SecureStoreChannel.kt), the iOS Keychain
// (SecureStoreChannel.swift), or the Windows Credential Manager
// (secure_store_channel.cpp). The channel is a plain key-value store:
//
//   read(key) -> String?      write(key, value) -> null      delete(key) -> null
//
// Keys are app-defined strings (see UploadDestination.secretKey). Values are
// UTF-8 strings. A missing key reads as null; deleting a missing key is a
// no-op. Any platform failure surfaces as [SecretStoreException].
// =============================================================================

import 'package:flutter/services.dart';

/// Key-value store for credentials.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Thrown when the platform keychain refuses or is unavailable.
class SecretStoreException implements Exception {
  const SecretStoreException(this.message);
  final String message;

  @override
  String toString() => 'SecretStoreException: $message';
}

/// The keychain-backed store used in the app.
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.birdnet/secure_store',
  );

  final MethodChannel _channel;

  @override
  Future<String?> read(String key) async {
    try {
      return await _channel.invokeMethod<String>('read', {'key': key});
    } on PlatformException catch (e) {
      throw SecretStoreException(e.message ?? e.code);
    } on MissingPluginException {
      throw const SecretStoreException('secure store unavailable');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
    } on PlatformException catch (e) {
      throw SecretStoreException(e.message ?? e.code);
    } on MissingPluginException {
      throw const SecretStoreException('secure store unavailable');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
    } on PlatformException catch (e) {
      throw SecretStoreException(e.message ?? e.code);
    } on MissingPluginException {
      throw const SecretStoreException('secure store unavailable');
    }
  }
}

/// Store for tests and previews; keeps secrets in a map.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
