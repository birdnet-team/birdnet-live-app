// =============================================================================
// App Launch Target Service Tests
// =============================================================================

import 'package:birdnet_live/shared/services/app_launch_target_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAppLaunchTarget', () {
    test('parses live target', () {
      expect(parseAppLaunchTarget('live'), AppLaunchTarget.live);
    });

    test('returns null for unknown target', () {
      expect(parseAppLaunchTarget('survey'), isNull);
    });

    test('returns null for null target', () {
      expect(parseAppLaunchTarget(null), isNull);
    });
  });
}
