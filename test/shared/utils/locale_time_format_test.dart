import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:birdnet_live/shared/utils/locale_time_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  test('formats dates with the requested locale', () {
    final date = DateTime(2026, 7, 31, 14, 5);

    expect(formatLocaleDate(date, 'de'), contains('31'));
    expect(formatLocaleDate(date, 'de'), contains('Juli'));
    expect(formatLocaleDate(date, 'en'), contains('Jul'));
  });

  test('separates the localized date and time with a dash', () {
    final date = DateTime(2026, 7, 31, 14, 5);
    final formatted = formatLocaleDateTime(
      date,
      'de',
      alwaysUse24HourFormat: true,
    );

    expect(formatted, contains('31'));
    expect(formatted, contains('14:05'));
    expect(formatted, contains(' - '));
    expect(formatted, isNot(contains(' at ')));
  });
}
