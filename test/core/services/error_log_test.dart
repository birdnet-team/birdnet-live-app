import 'dart:io';

import 'package:birdnet_live/core/services/error_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late int originalMaxBytes;
  late int originalMaxEntriesPerWindow;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('error_log_test');
    originalMaxBytes = ErrorLog.maxBytes;
    originalMaxEntriesPerWindow = ErrorLog.maxEntriesPerWindow;
    ErrorLog.directoryProvider = () async => tmp;
    ErrorLog.resetForTesting();
  });

  tearDown(() async {
    ErrorLog.maxBytes = originalMaxBytes;
    ErrorLog.maxEntriesPerWindow = originalMaxEntriesPerWindow;
    ErrorLog.clock = DateTime.now;
    ErrorLog.resetForTesting();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('entries carry a timestamp, context, error, and stack', () {
    final entry = ErrorLog.format(
      StateError('boom'),
      StackTrace.fromString('#0 a\n#1 b'),
      context: 'uncaught',
    );
    expect(entry, startsWith('['));
    expect(entry, contains('] uncaught: Bad state: boom'));
    expect(entry, contains('    #0 a'));
    expect(entry, contains('    #1 b'));
  });

  test('long stacks are cut at the top frames', () {
    final frames = List.generate(ErrorLog.maxStackLines + 5, (i) => '#$i f');
    final entry = ErrorLog.format(
      'x',
      StackTrace.fromString(frames.join('\n')),
    );
    expect(entry, contains('#${ErrorLog.maxStackLines - 1} f'));
    expect(entry, isNot(contains('#${ErrorLog.maxStackLines} f')));
    expect(entry, contains('... 5 more'));
  });

  test('an oversized description is cut short', () {
    final entry = ErrorLog.format(
      'z' * (ErrorLog.maxDescriptionChars + 10),
      null,
    );
    expect(entry, contains('... (10 more characters)'));
    expect(entry.length, lessThan(ErrorLog.maxDescriptionChars + 100));
  });

  test('records are appended in order to the log file', () async {
    ErrorLog.record('first', null, context: 'a');
    ErrorLog.record('second', null, context: 'b');
    await ErrorLog.flush();

    final file = (await ErrorLog.file())!;
    expect(file.path, '${tmp.path}/logs/${ErrorLog.fileName}');
    final content = file.readAsStringSync();
    expect(content.indexOf('a: first'), lessThan(content.indexOf('b: second')));
  });

  test('the file is trimmed to its newest entries', () async {
    ErrorLog.maxBytes = 2000;
    ErrorLog.maxEntriesPerWindow = 1000;
    for (var i = 0; i < 60; i++) {
      ErrorLog.record('entry number $i ${'x' * 40}', null);
    }
    await ErrorLog.flush();

    final file = (await ErrorLog.file())!;
    final content = file.readAsStringSync();
    expect(file.lengthSync(), lessThanOrEqualTo(2000));
    expect(content, startsWith('['));
    expect(content, contains('entry number 59'));
    expect(content, isNot(contains('entry number 0 ')));
  });

  test('an entry larger than half the limit survives the trim', () async {
    ErrorLog.maxBytes = 2000;
    ErrorLog.record('small', null);
    ErrorLog.record('big ${'y' * 2500} end', null);
    await ErrorLog.flush();

    final file = (await ErrorLog.file())!;
    final content = file.readAsStringSync();
    expect(file.lengthSync(), lessThanOrEqualTo(2000));
    expect(content, isNotEmpty);
    expect(content, endsWith('end\n'));
  });

  test('a storm of errors is capped per window and the rest counted', () async {
    var now = DateTime.utc(2026, 10, 11, 12);
    ErrorLog.clock = () => now;
    final limit = ErrorLog.maxEntriesPerWindow;
    for (var i = 0; i < limit + 7; i++) {
      ErrorLog.record('storm $i', null);
    }
    await ErrorLog.flush();

    final file = (await ErrorLog.file())!;
    var content = file.readAsStringSync();
    expect(content, contains('storm ${limit - 1}\n'));
    expect(content, isNot(contains('storm $limit\n')));
    expect(content, isNot(contains('dropped')));

    // Still inside the window: dropped, not written.
    now = now.add(ErrorLog.rateWindow - const Duration(seconds: 1));
    ErrorLog.record('late in window', null);
    await ErrorLog.flush();
    expect(file.readAsStringSync(), isNot(contains('late in window')));

    now = now.add(const Duration(seconds: 1));
    ErrorLog.record('next window', null);
    await ErrorLog.flush();
    content = file.readAsStringSync();
    expect(content, contains('rate limit: 8 entries dropped'));
    expect(
      content.indexOf('dropped'),
      lessThan(content.indexOf('next window')),
    );
  });

  test('an unavailable directory makes recording a no-op', () async {
    ErrorLog.directoryProvider = () async => throw StateError('no disk');
    ErrorLog.resetForTesting();

    ErrorLog.record('lost', null);
    await ErrorLog.flush();

    expect(await ErrorLog.file(), isNull);
  });
}
