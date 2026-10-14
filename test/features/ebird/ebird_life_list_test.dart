// =============================================================================
// EbirdLifeList Tests
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/ebird/ebird_life_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<EbirdLifeList> freshList() async {
    final prefs = await SharedPreferences.getInstance();
    return EbirdLifeList(prefs)..load();
  }

  test('starts empty before any import', () async {
    final list = await freshList();
    expect(list.isEmpty, isTrue);
    expect(list.length, 0);
    expect(list.importedAt, isNull);
    expect(list.contains('Turdus merula'), isFalse);
  });

  test('imports a well-formed eBird CSV export', () async {
    final list = await freshList();
    const csv =
        'Row #,Taxon Order,Category,Common Name,Scientific Name,Count\n'
        '1,6064,species,American Woodcock,Scolopax minor,2\n'
        '2,6061,species,Long-billed Dowitcher,Limnodromus scolopaceus,11\n';
    final count = await list.importCsv(csv);
    expect(count, 2);
    expect(list.length, 2);
    expect(list.isEmpty, isFalse);
    expect(list.contains('Scolopax minor'), isTrue);
    expect(list.contains('Limnodromus scolopaceus'), isTrue);
    expect(list.contains('Turdus merula'), isFalse);
    expect(list.importedAt, isNotNull);
  });

  test('handles quoted fields containing commas', () async {
    final list = await freshList();
    const csv =
        'Row #,Common Name,Scientific Name,Location\n'
        '1,American Robin,Turdus migratorius,"Springfield, IL"\n';
    await list.importCsv(csv);
    expect(list.contains('Turdus migratorius'), isTrue);
  });

  test('matches the Scientific Name column by header, not position',
      () async {
    final list = await freshList();
    const csv =
        'Scientific Name,Common Name,Row #\n'
        'Turdus migratorius,American Robin,1\n';
    await list.importCsv(csv);
    expect(list.contains('Turdus migratorius'), isTrue);
  });

  test('throws EbirdCsvFormatException when Scientific Name column is missing',
      () async {
    final list = await freshList();
    const csv = 'Common Name,Count\nAmerican Robin,1\n';
    expect(
      () => list.importCsv(csv),
      throwsA(isA<EbirdCsvFormatException>()),
    );
  });

  test('throws EbirdCsvFormatException for empty content', () async {
    final list = await freshList();
    expect(() => list.importCsv(''), throwsA(isA<EbirdCsvFormatException>()));
  });

  test('skips blank lines and rows missing the scientific name field',
      () async {
    final list = await freshList();
    const csv =
        'Common Name,Scientific Name\n'
        '\n'
        'American Robin,Turdus migratorius\n'
        'Unknown,\n';
    final count = await list.importCsv(csv);
    expect(count, 1);
    expect(list.contains('Turdus migratorius'), isTrue);
  });

  test('re-importing replaces the previous list entirely', () async {
    final list = await freshList();
    await list.importCsv(
      'Scientific Name\nTurdus migratorius\n',
    );
    expect(list.contains('Turdus migratorius'), isTrue);

    await list.importCsv('Scientific Name\nParus major\n');
    expect(list.contains('Turdus migratorius'), isFalse);
    expect(list.contains('Parus major'), isTrue);
    expect(list.length, 1);
  });

  test('persists across instances backed by the same prefs', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = EbirdLifeList(prefs)..load();
    await first.importCsv('Scientific Name\nTurdus migratorius\n');

    final second = EbirdLifeList(prefs)..load();
    expect(second.contains('Turdus migratorius'), isTrue);
    expect(second.importedAt, isNotNull);
  });

  test('clear wipes the list and the imported timestamp', () async {
    final list = await freshList();
    await list.importCsv('Scientific Name\nTurdus migratorius\n');
    expect(list.isEmpty, isFalse);

    await list.clear();
    expect(list.isEmpty, isTrue);
    expect(list.length, 0);
    expect(list.importedAt, isNull);
    expect(list.contains('Turdus migratorius'), isFalse);
  });

  test('notifies listeners on import and clear', () async {
    final list = await freshList();
    var notifications = 0;
    list.addListener(() => notifications++);

    await list.importCsv('Scientific Name\nTurdus migratorius\n');
    expect(notifications, 1);

    await list.clear();
    expect(notifications, 2);
  });
}
