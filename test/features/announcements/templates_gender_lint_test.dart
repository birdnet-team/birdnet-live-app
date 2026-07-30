// Lint-style test that scans the announcement templates for a gendered
// determiner (or demonstrative) placed directly in front of {name},
// {name1}, {name2}, {name3}.
//
// See dev/announcements.md §3.8.1. Many locales inflect the determiner in
// front of a noun by grammatical gender — der Zaunkönig / die Amsel /
// das Rotkehlchen; un merle / une mésange; de roodborst / het roodborstje.
// We don't carry a gender field on species names, so templates must never
// write a gendered determiner immediately before the name placeholder.
//
// Coverage notes:
//   - Article-gendered locales (de, nl, nb, fr, es, it) get a full article check.
//   - Portuguese deliberately checks only the *unambiguous* articles
//     (um/uma/uns/umas/os/as): the bare singular "o"/"a" double as a pronoun
//     and a preposition ("Soa a {name}." is the recommended *safe* pattern),
//     so flagging them would be a false positive.
//   - Slavic locales (pl, ru) have no articles, but a demonstrative before the
//     name forces gender agreement, so ten/ta/to · этот/эта/это… are flagged.
//     This is a PARTIAL check: case government and past-tense gender agreement
//     cannot be caught by a regex and still need a human review of new lines.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Determiners / demonstratives (lowercased) that must never sit directly
  // before {name*}. English is intentionally absent — `a`/`the` are
  // gender-neutral.
  const forbidden = <String, List<String>>{
    'de': [
      'ein', 'eine', 'einen', 'einem', 'einer', 'eines', //
      'der', 'die', 'das', 'dem', 'den', 'des',
    ],
    'nl': ['de', 'het', 'een'],
    'nb': ['en', 'ei', 'et', 'den', 'det', 'denne', 'dette', 'disse'],
    'fr': ['un', 'une', 'le', 'la', 'les', 'du', 'des'],
    'es': ['el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas'],
    'it': ['il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una'],
    'pt': ['um', 'uma', 'uns', 'umas', 'os', 'as'],
    'pl': ['ten', 'ta', 'to'],
    'ru': ['этот', 'эта', 'это', 'эти', 'тот', 'та', 'то'],
  };

  forbidden.forEach((locale, determiners) {
    test('templates_$locale.json: no gendered determiner before {name*}', () {
      final file = File('assets/announcements/templates_$locale.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Template file missing for locale "$locale"',
      );
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final buckets = json['buckets'] as Map<String, dynamic>;

      // (start-or-space) + determiner + space(s) + {name} / {name1..3}.
      // Matched against a lowercased copy of the line so it works for both
      // Latin and Cyrillic regardless of case-folding quirks.
      final pattern = RegExp(
        '(?:^|\\s)(${determiners.join('|')})\\s+\\{name\\d?\\}',
        unicode: true,
      );

      final offenders = <String>[];
      for (final entry in buckets.entries) {
        final bucketKey = entry.key;
        final bucket = entry.value as Map<String, dynamic>;
        for (final variantList in bucket.entries) {
          final verbosity = variantList.key;
          final variants = (variantList.value as List).cast<String>();
          for (final v in variants) {
            if (pattern.hasMatch(v.toLowerCase())) {
              offenders.add('  [$bucketKey/$verbosity] $v');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Gendered determiner detected before {name*} placeholder in '
            '"$locale". See dev/announcements.md §3.8.1 for safe phrasing '
            'patterns.\n${offenders.join('\n')}',
      );
    });
  });
}
