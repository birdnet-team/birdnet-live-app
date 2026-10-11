import 'package:birdnet_live/features/announcements/platform/tts_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted stand-in for the native `com.birdnet/tts` halves.
class _FakePlatform {
  final List<MethodCall> calls = [];
  Set<String> availableLanguages = {};
  List<Map<String, String>> voices = [];

  List<String> get languagesSet => [
    for (final c in calls)
      if (c.method == 'setLanguage') c.arguments['tag'] as String,
  ];

  List<Map<String, String>> get voicesSet => [
    for (final c in calls)
      if (c.method == 'setVoice')
        {
          'name': c.arguments['name'] as String,
          'locale': c.arguments['locale'] as String,
        },
  ];

  double? get rate => _lastDouble('setRate', 'rate');
  double? get pitch => _lastDouble('setPitch', 'pitch');

  double? _lastDouble(String method, String key) {
    double? value;
    for (final c in calls) {
      if (c.method == method) value = c.arguments[key] as double;
    }
    return value;
  }

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'setLanguage':
        return availableLanguages.contains(call.arguments['tag']);
      case 'setVoice':
        return voices.any(
          (v) =>
              v['name'] == call.arguments['name'] &&
              v['locale'] == call.arguments['locale'],
        );
      case 'getVoices':
        return voices;
      case 'speak':
        return true;
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;

  setUp(() {
    platform = _FakePlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          PlatformTtsEngine.defaultChannel,
          platform.handle,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformTtsEngine.defaultChannel, null);
  });

  test('configure resolves language down the fallback chain', () async {
    platform.availableLanguages = {'de'};
    final engine = PlatformTtsEngine();

    await engine.configure(languageTag: 'de-DE', rate: 1.2, pitch: 0.9);

    // Exact tag probed first, language-only accepted, chain stops there.
    expect(platform.languagesSet, ['de-DE', 'de']);
    expect(platform.rate, closeTo(1.2, 0.0001));
    expect(platform.pitch, closeTo(0.9, 0.0001));
  });

  test('configure falls back to English when nothing else is installed', () async {
    platform.availableLanguages = {'en-US'};
    final engine = PlatformTtsEngine();

    await engine.configure(languageTag: 'cs-CZ', rate: 1, pitch: 1);

    expect(platform.languagesSet, ['cs-CZ', 'cs', 'en-US']);
  });

  test('configure skips platform calls when nothing changed', () async {
    platform.availableLanguages = {'de-DE'};
    final engine = PlatformTtsEngine();

    await engine.configure(languageTag: 'de-DE', rate: 1, pitch: 1);
    final before = platform.calls.length;
    await engine.configure(languageTag: 'de-DE', rate: 1, pitch: 1);

    expect(platform.calls.length, before);
  });

  test(
    'configure only applies a pinned voice for the resolved language',
    () async {
      platform
        ..availableLanguages = {'de'}
        ..voices = [
          {'name': 'Shared name', 'locale': 'en-US'},
          {'name': 'German voice', 'locale': 'de-DE'},
        ];
      final engine = PlatformTtsEngine();

      await engine.configure(
        languageTag: 'de-DE',
        rate: 1,
        pitch: 1,
        voiceName: 'Shared name',
      );
      // The English voice is not applied; the language is reapplied so no
      // stale pin can survive.
      expect(platform.voicesSet, isEmpty);
      expect(platform.languagesSet, ['de-DE', 'de', 'de']);

      await engine.configure(
        languageTag: 'de-DE',
        rate: 1,
        pitch: 1,
        voiceName: 'German voice',
      );
      expect(platform.voicesSet.single, {
        'name': 'German voice',
        'locale': 'de-DE',
      });
    },
  );

  test('voicesForLanguage filters and sorts installed voices', () async {
    platform.voices = [
      {'name': 'Zulu', 'locale': 'de-DE'},
      {'name': 'English', 'locale': 'en-US'},
      {'name': 'alpha', 'locale': 'de-AT'},
    ];
    final engine = PlatformTtsEngine();

    final voices = await engine.voicesForLanguage('de');

    expect(voices, const [
      TtsVoice(name: 'alpha', locale: 'de-AT'),
      TtsVoice(name: 'Zulu', locale: 'de-DE'),
    ]);
  });

  test('speak cancels any in-flight utterance first', () async {
    final engine = PlatformTtsEngine();

    await engine.speak('Amsel');

    expect(platform.calls.map((c) => c.method), ['stop', 'speak']);
    expect(platform.calls.last.arguments, {'text': 'Amsel'});
  });

  test('speak ignores blank text', () async {
    final engine = PlatformTtsEngine();

    await engine.speak('   ');

    expect(platform.calls, isEmpty);
  });

  test('speak guard scales with text length and slows with rate', () {
    final short = PlatformTtsEngine.speakGuard('Amsel', 1.0);
    final long = PlatformTtsEngine.speakGuard('Amsel ' * 20, 1.0);
    final slow = PlatformTtsEngine.speakGuard('Amsel ' * 20, 0.5);

    expect(short, greaterThanOrEqualTo(const Duration(seconds: 6)));
    expect(long, greaterThan(short));
    expect(slow, greaterThan(long));
  });
}
