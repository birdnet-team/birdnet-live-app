import 'package:birdnet_live/features/history/export_device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.birdnet/device_description'),
          null,
        );
  });

  test(
    'reads only the public model and OS fields from the native channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.birdnet/device_description'),
            (call) async => {
              'model': 'Pixel 10',
              'brand': 'Google',
              'os': 'Android',
              'version': '17',
              'deviceId': 'private-id',
            },
          );

      expect(await exportDeviceInfo(), (device: 'Pixel 10', os: 'Android 17'));
    },
  );

  test('keeps consumer model and OS version', () {
    expect(
      formatExportDeviceInfo(
        platform: 'Android',
        model: 'Pixel 10',
        brand: 'Google',
        version: '17',
      ),
      (device: 'Pixel 10', os: 'Android 17'),
    );
    expect(
      formatExportDeviceInfo(
        platform: 'iOS',
        model: 'iPhone 17 Pro',
        version: '19.0',
      ),
      (device: 'iPhone 17 Pro', os: 'iOS 19.0'),
    );
  });

  test('replaces hardware codes with broad device names', () {
    expect(
      formatExportDeviceInfo(
        platform: 'Android',
        model: 'SM-S918B',
        brand: 'Samsung',
        version: '16',
      ),
      (device: 'Samsung device', os: 'Android 16'),
    );
    expect(
      formatExportDeviceInfo(
        platform: 'iOS',
        model: 'iPhone18,1',
        version: '19.0',
      ),
      (device: 'iPhone or iPad', os: 'iOS 19.0'),
    );
    expect(formatExportDeviceInfo(platform: 'Windows', version: '11'), (
      device: 'Windows PC',
      os: 'Windows 11',
    ));
    expect(formatExportDeviceInfo(platform: 'Linux'), (
      device: 'Linux computer',
      os: 'Linux',
    ));
  });
}
