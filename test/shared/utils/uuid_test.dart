import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/shared/utils/uuid.dart';

void main() {
  group('generateUuidV4', () {
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('produces canonical lowercase version 4 UUIDs', () {
      for (var i = 0; i < 200; i++) {
        expect(generateUuidV4(), matches(v4));
      }
    });

    test('does not repeat', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        expect(seen.add(generateUuidV4()), isTrue);
      }
    });
  });
}
