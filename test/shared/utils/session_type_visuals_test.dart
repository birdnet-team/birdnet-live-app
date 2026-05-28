import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/shared/utils/session_type_visuals.dart';

void main() {
  group('sessionTypeIcon', () {
    test('maps each session type to a stable icon', () {
      expect(sessionTypeIcon(SessionType.live), AppIcons.micRounded);
      expect(
        sessionTypeIcon(SessionType.pointCount),
        AppIcons.locationOnRounded,
      );
      expect(sessionTypeIcon(SessionType.survey), AppIcons.routeRounded);
      expect(sessionTypeIcon(SessionType.fileUpload), AppIcons.audioFileRounded);
    });
  });

  group('sessionTypePalette', () {
    test('uses white onAccent for brand light theme', () {
      final palette = sessionTypePalette(AppTheme.light(), SessionType.live);
      expect(palette.onAccent, Colors.white);
    });

    test('uses white onAccent for brand dark theme', () {
      final palette = sessionTypePalette(AppTheme.dark(), SessionType.live);
      expect(palette.onAccent, Colors.white);
    });

    test('uses brightness-based onAccent for non-brand theme', () {
      const customScheme = ColorScheme.light(
        primary: Colors.purple,
        primaryContainer: Colors.deepPurple,
      );
      final theme = ThemeData.from(colorScheme: customScheme);

      final palette = sessionTypePalette(theme, SessionType.survey);

      expect(palette.onContainer, theme.colorScheme.onSurface);
      expect(palette.onAccent, isNotNull);
      expect(palette.container, isNot(equals(palette.accent)));
    });
  });
}
