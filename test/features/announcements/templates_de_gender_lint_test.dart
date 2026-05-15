// Lint-style test that scans the German announcement templates for
// gendered articles in front of {name}, {name1}, {name2}, {name3}.
//
// See dev/announcements.md §3.8.1 — German bird names are gendered
// (der Zaunkönig, die Amsel, das Rotkehlchen) and we don't carry a
// gender field. Templates must avoid every form of `ein`, `eine`,
// `der`, `die`, `das` etc. immediately before the name placeholder.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'templates_de.json contains no gendered article in front of {name*}',
    () {
      final file = File('assets/announcements/templates_de.json');
      expect(file.existsSync(), isTrue, reason: 'German template file missing');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final buckets = json['buckets'] as Map<String, dynamic>;

      // Determiners + indefinite pronouns that inflect by gender.
      // Word-boundaried so substrings like "Wieder" don't trip the check.
      final forbidden = RegExp(
        r'\b(ein|eine|einen|einem|einer|eines|der|die|das|dem|den|des)\s+'
        r'\{name\d?\}',
        caseSensitive: false,
      );

      final offenders = <String>[];
      for (final entry in buckets.entries) {
        final bucketKey = entry.key;
        final bucket = entry.value as Map<String, dynamic>;
        for (final variantList in bucket.entries) {
          final verbosity = variantList.key;
          final variants = (variantList.value as List).cast<String>();
          for (final v in variants) {
            if (forbidden.hasMatch(v)) {
              offenders.add('  [$bucketKey/$verbosity] $v');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Gendered article detected before {name*} placeholder. '
            'See dev/announcements.md §3.8.1 for safe phrasing patterns.\n'
            '${offenders.join('\n')}',
      );
    },
  );
}
