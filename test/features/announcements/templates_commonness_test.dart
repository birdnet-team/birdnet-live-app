// Guards the Explore-aligned commonness phrasing:
//   1. The announcement's [CommonnessBin] stays 1:1 with Explore's
//      [ExploreTier] (same six semantic levels, same names) — the geo
//      provider maps one to the other and the template JSON keys are the
//      bin names, so a drift here would silently drop phrasing.
//   2. Every shipped locale defines a non-empty phrase list for all six
//      tiers, so no language silently falls back to bare bucket text for
//      the chatty commonness hint (in particular the frequent/scarce tiers
//      added alongside the Explore-tier alignment).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/explore/explore_tier.dart';

void main() {
  const locales = [
    'en',
    'de',
    'fr',
    'es',
    'it',
    'pt',
    'cs',
    'nl',
    'pl',
    'ru',
    'zh',
  ];

  test('CommonnessBin mirrors ExploreTier (same level names)', () {
    final bins = CommonnessBin.values.map((e) => e.name).toSet();
    final tiers = ExploreTier.values.map((e) => e.name).toSet();
    expect(
      bins,
      tiers,
      reason:
          'Announcement commonness bins must stay 1:1 with Explore tiers so '
          'the spoken hint matches the Explore card and template keys resolve.',
    );
  });

  for (final locale in locales) {
    test('templates_$locale.json defines every commonness tier', () {
      final file = File('assets/announcements/templates_$locale.json');
      expect(file.existsSync(), isTrue, reason: 'missing template: $locale');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final commonness = json['commonness'] as Map<String, dynamic>?;
      expect(commonness, isNotNull, reason: '$locale has no commonness block');
      for (final bin in CommonnessBin.values) {
        final list = commonness![bin.name];
        expect(
          list,
          isA<List>(),
          reason: '$locale is missing commonness tier "${bin.name}"',
        );
        expect(
          (list as List).isNotEmpty,
          isTrue,
          reason: '$locale commonness tier "${bin.name}" is empty',
        );
      }
      expect(
        commonness!['seasonalAddendum'],
        isA<List>(),
        reason: '$locale is missing the seasonalAddendum list',
      );
    });
  }
}
