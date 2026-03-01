// =============================================================================
// Custom Species List Tests
// =============================================================================
//
// Tests the plain-text parsing logic of CustomSpeciesList.  Persistence tests
// (save/load/delete) are skipped because they require path_provider which
// needs a running Flutter host.
// =============================================================================

import 'package:birdnet_live/features/inference/custom_species_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomSpeciesList.parse', () {
    test('parses simple list', () {
      const content = '''Parus major
Turdus merula
Erithacus rubecula''';

      final result = CustomSpeciesList.parse(content);

      expect(result.length, 3);
      expect(result, contains('Parus major'));
      expect(result, contains('Turdus merula'));
      expect(result, contains('Erithacus rubecula'));
    });

    test('trims whitespace', () {
      const content = '  Parus major  \n  Turdus merula  ';
      final result = CustomSpeciesList.parse(content);
      expect(result, contains('Parus major'));
      expect(result, contains('Turdus merula'));
    });

    test('ignores blank lines', () {
      const content = 'Parus major\n\n\nTurdus merula\n\n';
      final result = CustomSpeciesList.parse(content);
      expect(result.length, 2);
    });

    test('ignores comment lines starting with #', () {
      const content = '''# European songbirds
Parus major
# Thrushes
Turdus merula
# This is a comment''';

      final result = CustomSpeciesList.parse(content);
      expect(result.length, 2);
      expect(result, isNot(contains('# European songbirds')));
    });

    test('deduplicates entries', () {
      const content = 'Parus major\nParus major\nParus major';
      final result = CustomSpeciesList.parse(content);
      expect(result.length, 1);
    });

    test('handles Windows-style line endings', () {
      const content = 'Parus major\r\nTurdus merula\r\n';
      final result = CustomSpeciesList.parse(content);
      expect(result.length, 2);
    });

    test('empty string returns empty set', () {
      expect(CustomSpeciesList.parse(''), isEmpty);
    });

    test('whitespace-only string returns empty set', () {
      expect(CustomSpeciesList.parse('   \n  \n  '), isEmpty);
    });

    test('comments-only string returns empty set', () {
      const content = '# comment 1\n# comment 2';
      expect(CustomSpeciesList.parse(content), isEmpty);
    });

    test('handles single species', () {
      final result = CustomSpeciesList.parse('Parus major');
      expect(result.length, 1);
      expect(result.first, 'Parus major');
    });
  });
}
