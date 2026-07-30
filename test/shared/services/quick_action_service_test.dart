import 'package:birdnet_live/shared/services/quick_action_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickListenSafety', () {
    tearDown(QuickListenSafety.reset);

    test('tracks the active incompatible recording screen by owner token', () {
      final owner = Object();

      QuickListenSafety.registerIncompatibleSessionOwner(
        owner,
        QuickListenSessionOwner.pointCount,
      );

      expect(
        QuickListenSafety.activeSessionOwner,
        QuickListenSessionOwner.pointCount,
      );
    });

    test('registration is idempotent for the same owner token', () {
      final owner = Object();
      QuickListenSafety.registerIncompatibleSessionOwner(
        owner,
        QuickListenSessionOwner.pointCount,
      );
      QuickListenSafety.registerIncompatibleSessionOwner(
        owner,
        QuickListenSessionOwner.survey,
      );

      QuickListenSafety.unregisterIncompatibleSessionOwner(owner);

      expect(QuickListenSafety.activeSessionOwner, isNull);
    });

    test('unregistering one overlapping route preserves the other', () {
      final pointCountOwner = Object();
      final surveyOwner = Object();
      QuickListenSafety.registerIncompatibleSessionOwner(
        pointCountOwner,
        QuickListenSessionOwner.pointCount,
      );
      QuickListenSafety.registerIncompatibleSessionOwner(
        surveyOwner,
        QuickListenSessionOwner.survey,
      );

      QuickListenSafety.unregisterIncompatibleSessionOwner(pointCountOwner);

      expect(
        QuickListenSafety.activeSessionOwner,
        QuickListenSessionOwner.survey,
      );
    });
  });
}
