import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/features/file_analysis/file_analysis_screen.dart';
import 'package:birdnet_live/shared/services/shared_media_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedMediaService.importSharedFile', () {
    const channel = MethodChannel('com.birdnet/shared_media');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('passes the URI and display name to the platform', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return '/cache/shared_audio/dawn-chorus.wav';
      });

      final path = await SharedMediaService.importSharedFile(
        const SharedAudioFile(
          uri: 'content://media/audio/42',
          name: 'dawn-chorus.wav',
        ),
      );

      expect(path, '/cache/shared_audio/dawn-chorus.wav');
      expect(received?.method, 'importSharedFile');
      expect(received?.arguments, {
        'uri': 'content://media/audio/42',
        'name': 'dawn-chorus.wav',
      });
    });

    test('throws when the platform returns no path', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(
        () => SharedMediaService.importSharedFile(
          const SharedAudioFile(uri: 'content://media/audio/42', name: ''),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('serializes imports that replace the shared cache file', () async {
      final firstPlatformResult = Completer<String>();
      final secondInvocation = Completer<void>();
      var invocationCount = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        invocationCount++;
        if (invocationCount == 1) return firstPlatformResult.future;
        secondInvocation.complete();
        return '/cache/shared_audio/second.wav';
      });

      final firstImport = SharedMediaService.importSharedFile(
        const SharedAudioFile(uri: 'content://media/audio/1', name: 'one.wav'),
      );
      final secondImport = SharedMediaService.importSharedFile(
        const SharedAudioFile(uri: 'content://media/audio/2', name: 'two.wav'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(invocationCount, 1);

      firstPlatformResult.complete('/cache/shared_audio/first.wav');
      expect(await firstImport, '/cache/shared_audio/first.wav');
      await secondInvocation.future.timeout(const Duration(seconds: 1));
      expect(await secondImport, '/cache/shared_audio/second.wav');
      expect(invocationCount, 2);
    });
  });

  group('SharedMediaService.discardSharedFile', () {
    const channel = MethodChannel('com.birdnet/shared_media');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('asks the platform to release the staging copy', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });

      await SharedMediaService.discardSharedFile(
        const SharedAudioFile(uri: 'file:///Inbox/dawn.wav', name: 'dawn.wav'),
      );

      expect(received?.method, 'discardSharedFile');
      expect(received?.arguments, {'uri': 'file:///Inbox/dawn.wav'});
    });

    test('swallows platform failures', () async {
      // Callers are already giving up on the file; a failed cleanup must not
      // turn into an unhandled error on top of that.
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'IMPORT_ERROR');
      });

      await expectLater(
        SharedMediaService.discardSharedFile(
          const SharedAudioFile(uri: 'file:///Inbox/dawn.wav', name: ''),
        ),
        completes,
      );
    });

    test('runs behind an import already in flight', () async {
      final importResult = Completer<String>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'importSharedFile') return importResult.future;
        return null;
      });

      final import = SharedMediaService.importSharedFile(
        const SharedAudioFile(uri: 'content://1', name: 'one.wav'),
      );
      final discard = SharedMediaService.discardSharedFile(
        const SharedAudioFile(uri: 'content://2', name: 'two.wav'),
      );

      // The discard empties the same staging directory the import is reading
      // from, so it must not overlap with it.
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['importSharedFile']);

      importResult.complete('/cache/shared_audio/one.wav');
      await import;
      await discard;
      expect(calls, ['importSharedFile', 'discardSharedFile']);
    });
  });

  group('FileAnalysisScreenPresence', () {
    test('reports the most recently mounted route', () {
      final first = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final second = MaterialPageRoute<void>(builder: (_) => const SizedBox());

      FileAnalysisScreenPresence.register(first);
      FileAnalysisScreenPresence.register(second);
      expect(FileAnalysisScreenPresence.mountedRoute, second);

      // Overlapping routes during a transition: dropping the newer one must
      // leave the older one addressable rather than clearing presence.
      FileAnalysisScreenPresence.unregister(second);
      expect(FileAnalysisScreenPresence.mountedRoute, first);

      FileAnalysisScreenPresence.unregister(first);
      expect(FileAnalysisScreenPresence.mountedRoute, isNull);
    });

    test('registration is idempotent for the same route', () {
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());

      FileAnalysisScreenPresence.register(route);
      FileAnalysisScreenPresence.register(route);
      FileAnalysisScreenPresence.unregister(route);

      expect(FileAnalysisScreenPresence.mountedRoute, isNull);
    });
  });
}
