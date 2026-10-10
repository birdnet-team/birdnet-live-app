// =============================================================================
// File Analysis Screen Tests - Async location choice handling
// =============================================================================

import 'dart:async';

import 'package:birdnet_live/core/services/location_service.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_controller.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_providers.dart';
import 'package:birdnet_live/features/file_analysis/file_analysis_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final choice in ['None', 'Manual']) {
    testWidgets('late GPS does not override $choice location choice', (
      tester,
    ) async {
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _TestFilePicker();
      addTearDown(() => FilePickerPlatform.instance = originalPicker);
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pendingLocation = Completer<AppLocation?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileAnalysisControllerProvider.overrideWithValue(
              _TestAnalysisController(),
            ),
            currentLocationProvider.overrideWith(
              (ref) => pendingLocation.future,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FileAnalysisScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      if (choice == 'Manual') {
        final dynamic locationStep = tester.widget(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_LocationStep',
          ),
        );
        locationStep.onMapPick(48.137, 11.576);
        await tester.pump();
      }
      pendingLocation.complete(
        const AppLocation(latitude: 52.52, longitude: 13.405, altitude: 34.5),
      );
      await tester.pumpAndSettle();

      final dynamic locationStep = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_LocationStep',
        ),
      );
      expect(locationStep.latitude, choice == 'Manual' ? 48.137 : isNull);
      expect(locationStep.longitude, choice == 'Manual' ? 11.576 : isNull);
      expect(locationStep.locationName, isNull);
      expect(locationStep.isFetching, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}

class _TestAnalysisController extends FileAnalysisController {
  @override
  Future<AudioFileInfo> inspectFile(String path) async => AudioFileInfo(
    path: path,
    fileName: 'test.wav',
    fileSizeBytes: 48000,
    duration: const Duration(seconds: 1),
    sampleRate: 48000,
    totalSamples: 48000,
    format: 'WAV',
  );
}

class _TestFilePicker extends FilePickerPlatform {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidSAFOptions? androidSafOptions,
  }) async => FilePickerResult([
    PlatformFile(name: 'test.wav', path: 'test.wav', size: 48000),
  ]);
}
