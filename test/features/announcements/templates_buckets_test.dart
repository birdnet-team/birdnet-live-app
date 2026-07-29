// Guards bucket coverage in the spoken announcement templates.
//
// The sister test templates_commonness_test.dart covers the commonness
// block; this one covers the buckets themselves, which are the part a
// translator is most likely to leave incomplete:
//
//   1. Every shipped locale defines all ten buckets with a non-empty
//      `balanced` list. TemplateBundle.fromJson drops a bucket whose
//      `balanced` is missing or empty, and TemplateLibrary falls back to
//      `en` silently (by design — a translator typo must not crash the
//      runtime), so a gap here means the app quietly speaks English in
//      that locale with nothing in the logs to say so.
//
//   2. Placeholders match the bucket's slots. The engine substitutes
//      {name} for single-species buckets and {name1}/{name2}/{name3} for
//      the coalesce buckets; a template carrying the wrong placeholder
//      would be spoken with the literal braces in it.
//
// See dev/announcements.md §3.8 and assets/announcements/README.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/announcements/domain/announcement_buckets.dart';

void main() {
  const locales = ['en', 'de', 'fr', 'es', 'it', 'pt', 'cs', 'nl', 'pl', 'ru'];

  // Slots the engine fills per bucket. H_two deliberately has only two,
  // so a two-species coalesce never speaks a half-filled phrase.
  const slots = <AnnouncementBucket, List<String>>{
    AnnouncementBucket.hTwo: ['{name1}', '{name2}'],
    AnnouncementBucket.hThree: ['{name1}', '{name2}', '{name3}'],
    AnnouncementBucket.hMany: ['{name1}', '{name2}', '{name3}'],
  };
  const singleSlot = ['{name}'];

  List<String> slotsFor(AnnouncementBucket b) => slots[b] ?? singleSlot;

  for (final locale in locales) {
    group('templates_$locale.json', () {
      late Map<String, dynamic> buckets;

      setUpAll(() {
        final file = File('assets/announcements/templates_$locale.json');
        expect(file.existsSync(), isTrue, reason: 'missing template: $locale');
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(
          json['locale'],
          locale,
          reason: '$locale file declares the wrong "locale" tag',
        );
        final raw = json['buckets'];
        expect(raw, isA<Map>(), reason: '$locale has no buckets block');
        buckets = raw as Map<String, dynamic>;
      });

      test('defines every bucket with a non-empty balanced list', () {
        for (final bucket in AnnouncementBucket.values) {
          final node = buckets[bucket.jsonKey];
          expect(
            node,
            isA<Map>(),
            reason: '$locale is missing bucket "${bucket.jsonKey}"',
          );
          final balanced = (node as Map)['balanced'];
          expect(
            balanced,
            isA<List>(),
            reason: '$locale bucket "${bucket.jsonKey}" has no balanced list',
          );
          expect(
            (balanced as List).isNotEmpty,
            isTrue,
            reason: '$locale bucket "${bucket.jsonKey}" balanced list is empty '
                '— the loader drops it and this locale falls back to English',
          );
          // chatty is optional (falls back to balanced), but must not be
          // present-and-malformed.
          final chatty = node['chatty'];
          if (chatty != null) {
            expect(
              chatty,
              isA<List>(),
              reason: '$locale bucket "${bucket.jsonKey}" chatty is not a list',
            );
          }
        }
      });

      test('every variant carries exactly its bucket\'s placeholders', () {
        for (final bucket in AnnouncementBucket.values) {
          final node = buckets[bucket.jsonKey] as Map?;
          if (node == null) continue; // reported by the coverage test above
          final expected = slotsFor(bucket);
          final unexpected = ['{name}', '{name1}', '{name2}', '{name3}']
              .where((p) => !expected.contains(p));

          for (final variant in [
            ...?(node['balanced'] as List?),
            ...?(node['chatty'] as List?),
          ]) {
            if (variant is! String) continue;
            for (final placeholder in expected) {
              expect(
                variant.contains(placeholder),
                isTrue,
                reason: '$locale bucket "${bucket.jsonKey}" variant is missing '
                    '$placeholder: "$variant"',
              );
            }
            for (final placeholder in unexpected) {
              expect(
                variant.contains(placeholder),
                isFalse,
                reason: '$locale bucket "${bucket.jsonKey}" variant uses '
                    '$placeholder, which this bucket never fills: "$variant"',
              );
            }
          }
        }
      });
    });
  }
}
