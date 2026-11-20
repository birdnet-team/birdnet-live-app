import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/shared/services/setup_memory.dart';

enum _Choice { gps, manual, skip }

void main() {
  const key = 'test_setup_memory';

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('restores what was saved', () async {
    final prefs = await prefsWith({});
    await SetupMemory.save(prefs, key, {
      'choice': _Choice.skip.name,
      'threshold': 40,
      'sensitivity': 1.2,
      'whole': 1,
      'mode': 'geoMerge',
      'testCycle': false,
      'notRemembered': null,
    });

    final memory = SetupMemory.load(prefs, key);
    expect(memory.enumValue('choice', _Choice.values), _Choice.skip);
    expect(memory.intValue('threshold', min: 1, max: 99), 40);
    expect(memory.doubleValue('sensitivity', min: 0.5, max: 1.5), 1.2);
    // JSON drops the fraction of a whole number.
    expect(memory.doubleValue('whole'), 1.0);
    expect(
      memory.stringValue('mode', allowed: ['off', 'geoMerge']),
      'geoMerge',
    );
    expect(memory.boolValue('testCycle'), isFalse);
    expect(memory.stringValue('notRemembered'), isNull);
  });

  test('saving replaces the previous memory', () async {
    final prefs = await prefsWith({});
    await SetupMemory.save(prefs, key, {'threshold': 40, 'mode': 'off'});
    await SetupMemory.save(prefs, key, {'mode': 'geoMerge'});

    final memory = SetupMemory.load(prefs, key);
    expect(memory.intValue('threshold'), isNull);
    expect(memory.stringValue('mode'), 'geoMerge');
  });

  test('values that no longer fit are not restored', () async {
    final prefs = await prefsWith({});
    await SetupMemory.save(prefs, key, {
      'choice': 'teleport',
      'threshold': 140,
      'sensitivity': 0.1,
      'mode': 'customList',
      'testCycle': 'yes',
      'count': 2.5,
    });

    final memory = SetupMemory.load(prefs, key);
    expect(memory.enumValue('choice', _Choice.values), isNull);
    expect(memory.intValue('threshold', min: 1, max: 99), isNull);
    expect(memory.doubleValue('sensitivity', min: 0.5, max: 1.5), isNull);
    expect(memory.stringValue('mode', allowed: ['off', 'geoMerge']), isNull);
    expect(memory.boolValue('testCycle'), isNull);
    expect(memory.intValue('count'), isNull);
  });

  test('missing or corrupt memory is empty', () async {
    for (final stored in <Map<String, Object>>[
      {},
      {key: 'not json'},
      {key: '[1, 2]'},
      {key: 7},
    ]) {
      final memory = SetupMemory.load(await prefsWith(stored), key);
      expect(memory.intValue('threshold'), isNull);
      expect(memory.enumValue('choice', _Choice.values), isNull);
    }
  });
}
