// =============================================================================
// Shared Media Service — "Share with BirdNET Live" → File Analysis
// =============================================================================
//
// Bridges an audio file handed to the app by another app to Dart:
//
//   * Android — an ACTION_SEND (share sheet) or ACTION_VIEW ("open with")
//     intent carrying an `audio/*` URI. See the intent filters in
//     AndroidManifest.xml and `captureSharedMedia` in MainActivity.kt.
//   * iOS — either the ShareExtension target, which stages the attachment in
//     the shared App Group container for the app's next activation, or a
//     document opened through CFBundleDocumentTypes. AppDelegate.swift queues
//     both paths. See docs/developer/share-targets.md.
//
// Both platforms queue the incoming item natively and either forward it
// immediately (app already running — "warm" case) or hold it for
// [takePendingSharedFile] once Dart starts listening (app was killed — "cold"
// case). Mirrors `quick_action_service.dart`'s native-action bridge.
//
// The hand-off is deliberately two calls. The URI arrives instantly, so File
// Analysis can open on it; the copy into app storage — which for a long
// recording is hundreds of megabytes — runs afterwards under that screen's own
// progress indicator.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An audio file another app handed to us, before it has been imported.
class SharedAudioFile {
  const SharedAudioFile({required this.uri, required this.name});

  /// Platform URI of the shared item (`content://`, `file://`).
  final String uri;

  /// Display name reported by the source, empty when it provided none — or
  /// when the platform resolves it during the import instead, which is what
  /// Android does to keep a provider query off the launch path.
  final String name;
}

abstract final class SharedMediaService {
  static const MethodChannel _channel = MethodChannel(
    'com.birdnet/shared_media',
  );
  static Future<void> _importQueue = Future<void>.value();

  /// Whether this platform can receive shared files. Windows has no share
  /// target, so the listener stays inert there.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Returns the file queued natively before Dart attached a listener (cold
  /// start), or `null` if there is none.
  static Future<SharedAudioFile?> takePendingSharedFile() async {
    if (!isSupported) return null;
    final shared = await _channel.invokeMapMethod<String, dynamic>(
      'takePendingSharedFile',
    );
    if (shared == null) return null;
    final uri = shared['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;
    return SharedAudioFile(uri: uri, name: (shared['name'] as String?) ?? '');
  }

  /// Registers [handler] to be called when a file is shared while the app is
  /// already running (warm start). The handler is expected to drain the item
  /// with [takePendingSharedFile]. Pass `null` to detach.
  static void setNativeShareHandler(void Function()? handler) {
    if (!isSupported) return;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') handler();
      return null;
    });
  }

  /// Copies [file] into app storage and returns its local path.
  ///
  /// Only the most recent import is kept on disk, and it lives in the cache, so
  /// there is nothing for the app to clean up later. A successful import also
  /// releases the platform's staging copy of [file].
  static Future<String> importSharedFile(SharedAudioFile file) {
    return _serialized(() async {
      final path = await _channel.invokeMethod<String>('importSharedFile', {
        'uri': file.uri,
        'name': file.name,
      });
      if (path == null || path.isEmpty) {
        throw const FileSystemException('Shared file could not be imported');
      }
      return path;
    });
  }

  /// Releases the platform's staging copy of a file the app decided not to
  /// open, so a hand-off the user abandoned does not sit on disk forever.
  ///
  /// Only staging the app owns is removed. On iOS that is the document the
  /// system copied into `Documents/Inbox` or the ShareExtension's App Group
  /// copy — neither of which anything else prunes. Android has nothing to
  /// release: the URI belongs to the app that shared it.
  ///
  /// Best effort. A failure here only leaves a stale file behind, so it is
  /// logged rather than raised at a caller that is already giving up.
  static Future<void> discardSharedFile(SharedAudioFile file) {
    return _serialized(() async {
      try {
        await _channel.invokeMethod<void>('discardSharedFile', {
          'uri': file.uri,
        });
      } catch (error, stackTrace) {
        debugPrint('Shared file could not be discarded: $error\n$stackTrace');
      }
    });
  }

  /// Runs [action] after every native call already queued.
  ///
  /// Imports replace the previous file in a shared staging directory, so
  /// overlapping calls would delete or overwrite each other's source file — a
  /// rapidly replaced File Analysis route can produce exactly that overlap.
  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _importQueue = _importQueue.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
