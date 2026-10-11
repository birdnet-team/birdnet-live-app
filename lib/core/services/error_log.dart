// =============================================================================
// Error Log — bounded on-device record of uncaught errors
// =============================================================================
//
// An uncaught Dart error does not crash a release build: Flutter prints it
// and carries on, so a field report arrives as "it just stopped working" with
// nothing to look at. This hooks the two framework error funnels and appends
// each error to a small file in the app's support directory, keeping the
// default handling (console output) intact.
//
// Nothing here leaves the device. The file holds timestamps, error messages,
// and stack traces — no audio, no locations, no identifiers — and it is only
// ever read when a user chooses to share it.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Appends uncaught errors to `<app support>/logs/errors.log`.
class ErrorLog {
  ErrorLog._();

  static const String fileName = 'errors.log';

  /// The file is trimmed back to about half this size once it grows past it,
  /// dropping the oldest entries.
  static int maxBytes = 256 * 1024;

  /// Stack frames kept per entry; the top of the trace is what matters.
  static const int maxStackLines = 40;

  /// Characters of the error's own description kept per entry. A `toString`
  /// that carries a whole payload would otherwise dominate the file.
  static const int maxDescriptionChars = 4096;

  /// Entries accepted per [rateWindow]; the rest are only counted, and the
  /// count is written as one line when the next window opens. An error that
  /// fires every frame would otherwise turn the log into a continuous stream
  /// of synced appends and full-file rewrites for as long as it lasts.
  static int maxEntriesPerWindow = 20;

  /// See [maxEntriesPerWindow].
  static const Duration rateWindow = Duration(minutes: 1);

  static bool _installed = false;
  static Future<void> _writes = Future<void>.value();
  static Future<File?>? _file;
  static DateTime? _windowStart;
  static int _windowCount = 0;
  static int _dropped = 0;

  /// Where the log lives. Defaults to the platform support directory; tests
  /// point it at a temporary one.
  @visibleForTesting
  static Future<Directory> Function() directoryProvider =
      getApplicationSupportDirectory;

  /// The clock behind timestamps and the rate limit; tests drive it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Hook the framework's error funnels. Idempotent, and never throws.
  ///
  /// Both hooks chain to the handler that was installed before them, so the
  /// console output and any other reporting stay exactly as they were.
  static void install() {
    if (_installed) return;
    _installed = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record(
        details.exception,
        details.stack,
        context: details.library ?? 'flutter',
      );
      previousFlutterOnError?.call(details);
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'uncaught');
      // False keeps the error unhandled as far as the framework is concerned,
      // so it is still printed the way it was before the hook existed.
      return previousPlatformOnError?.call(error, stack) ?? false;
    };
  }

  /// Append one entry. Fire-and-forget: writes are serialized, and a failure
  /// to write is swallowed rather than reported through the hooks again.
  ///
  /// Past [maxEntriesPerWindow] entries in one [rateWindow] the rest of the
  /// window is dropped and counted; see there.
  static void record(Object error, StackTrace? stack, {String context = ''}) {
    final now = clock();
    final windowStart = _windowStart;
    if (windowStart == null || now.difference(windowStart) >= rateWindow) {
      if (_dropped > 0) {
        _enqueue(
          '[${_timestamp(now)}] rate limit: $_dropped entries dropped\n',
        );
      }
      _windowStart = now;
      _windowCount = 0;
      _dropped = 0;
    }
    if (_windowCount >= maxEntriesPerWindow) {
      _dropped++;
      return;
    }
    _windowCount++;
    _enqueue(format(error, stack, context: context));
  }

  static void _enqueue(String entry) {
    _writes = _writes.then((_) => _append(entry)).catchError((Object _) {});
  }

  static String _timestamp(DateTime time) => time.toUtc().toIso8601String();

  /// Completes once every entry recorded so far has been written.
  static Future<void> flush() => _writes;

  /// The log file, or null when the support directory is unavailable.
  static Future<File?> file() => _file ??= _locate();

  /// Forget the cached location (tests that change [directoryProvider]).
  @visibleForTesting
  static void resetForTesting() {
    _file = null;
    _writes = Future<void>.value();
    _windowStart = null;
    _windowCount = 0;
    _dropped = 0;
  }

  /// One log entry: a UTC timestamp, the context, the error, and the top of
  /// the stack.
  @visibleForTesting
  static String format(Object error, StackTrace? stack, {String context = ''}) {
    final buffer = StringBuffer()
      ..write('[')
      ..write(_timestamp(clock()))
      ..write('] ');
    if (context.isNotEmpty) buffer.write('$context: ');
    buffer.writeln(_describe(error));
    if (stack != null) {
      final lines = stack.toString().trimRight().split('\n');
      for (final line in lines.take(maxStackLines)) {
        buffer.writeln('    $line');
      }
      if (lines.length > maxStackLines) {
        buffer.writeln('    ... ${lines.length - maxStackLines} more');
      }
    }
    return buffer.toString();
  }

  static String _describe(Object error) {
    String text;
    try {
      text = error.toString();
    } catch (_) {
      text = error.runtimeType.toString();
    }
    if (text.length <= maxDescriptionChars) return text;
    return '${text.substring(0, maxDescriptionChars)}'
        '... (${text.length - maxDescriptionChars} more characters)';
  }

  static Future<File?> _locate() async {
    try {
      final dir = Directory('${(await directoryProvider()).path}/logs');
      await dir.create(recursive: true);
      return File('${dir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _append(String entry) async {
    final target = await file();
    if (target == null) return;
    await target.writeAsString(entry, mode: FileMode.append, flush: true);
    if (await target.length() > maxBytes) await _trim(target);
  }

  /// Keep the newest half of the file, starting on an entry boundary.
  ///
  /// When no entry starts inside that half — one entry larger than it — the
  /// tail is kept as it is rather than emptying the log, so the entry that
  /// pushed the file over the limit is not the one that disappears.
  static Future<void> _trim(File target) async {
    final content = await target.readAsString();
    var cut = content.length - maxBytes ~/ 2;
    if (cut < 0) cut = 0;
    final boundary = content.indexOf('\n[', cut);
    final kept = boundary < 0
        ? content.substring(cut)
        : content.substring(boundary + 1);
    await target.writeAsString(kept, flush: true);
  }
}
