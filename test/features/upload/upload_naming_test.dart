import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/upload/upload_naming.dart';

void main() {
  test('uploadDeviceCode is the first eight hex digits of the device id', () {
    expect(
      uploadDeviceCode('4ee91c8f-8383-4413-8320-3aa94f39221f'),
      '4ee91c8f',
    );
    expect(uploadDeviceCode('ABCDEF12-3456'), 'abcdef12');
    expect(uploadDeviceCode('abc'), 'abc');
  });
}
