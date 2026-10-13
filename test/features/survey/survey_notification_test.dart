import 'package:birdnet_live/features/survey/survey_notification.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurveyNotificationService.serviceTypesFor', () {
    test('always declares the microphone type', () {
      final types = SurveyNotificationService.serviceTypesFor(
        includeLocation: false,
        locationGranted: true,
      );
      expect(types, [ForegroundServiceTypes.microphone]);
    });

    test('adds location only when tracking and the permission is granted', () {
      expect(
        SurveyNotificationService.serviceTypesFor(
          includeLocation: true,
          locationGranted: true,
        ),
        [ForegroundServiceTypes.microphone, ForegroundServiceTypes.location],
      );
      expect(
        SurveyNotificationService.serviceTypesFor(
          includeLocation: true,
          locationGranted: false,
        ),
        [ForegroundServiceTypes.microphone],
      );
    });
  });
}
