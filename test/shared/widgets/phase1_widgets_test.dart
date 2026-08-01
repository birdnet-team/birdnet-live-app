// Tests for the Phase 1 shared widgets and the ScoreColors theme extension.

import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/core/theme/score_colors.dart';
import 'package:birdnet_live/shared/widgets/confirm_destructive.dart';
import 'package:birdnet_live/shared/widgets/empty_view.dart';
import 'package:birdnet_live/shared/widgets/error_view.dart';
import 'package:birdnet_live/shared/widgets/loading_view.dart';
import 'package:birdnet_live/shared/widgets/stat_chip.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  group('LoadingView', () {
    testWidgets('renders spinner without label when label is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders label beneath spinner when provided', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView(label: 'Loading…')));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
    });

    testWidgets('compact uses smaller spinner', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView(compact: true)));
      final size = tester.getSize(find.byType(CircularProgressIndicator).first);
      expect(size.width, lessThan(28));
    });
  });

  group('EmptyView', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyView(icon: Icons.search_off, title: 'Nothing here')),
      );
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('shows action when both label and callback provided', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyView(
            icon: Icons.search_off,
            title: 'Nothing here',
            actionLabel: 'Refresh',
            onAction: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Refresh'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(tapped, isTrue);
    });

    testWidgets('hides action when callback is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyView(
            icon: Icons.search_off,
            title: 'Nothing here',
            actionLabel: 'Refresh',
          ),
        ),
      );
      expect(find.text('Refresh'), findsNothing);
    });
  });

  group('ErrorView', () {
    testWidgets('renders default error icon and title', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorView(title: 'Oh no')));
      expect(find.byIcon(AppIcons.errorOutline), findsOneWidget);
      expect(find.text('Oh no'), findsOneWidget);
    });

    testWidgets('shows retry only when both label and callback provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ErrorView(title: 'Oh no', retryLabel: 'Retry')),
      );
      expect(find.text('Retry'), findsNothing);

      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ErrorView(
            title: 'Oh no',
            retryLabel: 'Retry',
            onRetry: () => retried = true,
          ),
        ),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('confirmDestructive', () {
    testWidgets('returns true when confirm tapped', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    future = confirmDestructive(
                      context,
                      title: 'Stop?',
                      body: 'This will end the session.',
                      confirmLabel: 'Stop',
                      cancelLabel: 'Cancel',
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('returns false when cancel tapped', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    future = confirmDestructive(
                      context,
                      title: 'Stop?',
                      body: 'This will end the session.',
                      confirmLabel: 'Stop',
                      cancelLabel: 'Cancel',
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    });

    testWidgets('returns false when dismissed via tap-outside', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    future = confirmDestructive(
                      context,
                      title: 'Stop?',
                      body: 'This will end the session.',
                      confirmLabel: 'Stop',
                      cancelLabel: 'Cancel',
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Tap outside the dialog (top-left corner of the barrier).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    });
  });

  group('StatChip', () {
    testWidgets('chip variant renders icon + value inline', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatChip(icon: Icons.timer_outlined, value: '2:34')),
      );
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.text('2:34'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('badge variant uses bold weight', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatChip(
            icon: Icons.timer_outlined,
            value: '2:34',
            variant: StatChipVariant.badge,
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('2:34'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('card variant renders boxed Card with optional label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatChip(
            icon: Icons.bar_chart,
            value: '142',
            label: 'Detections',
            variant: StatChipVariant.card,
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('Detections'), findsOneWidget);
    });
  });

  group('ScoreColors', () {
    test('forScore buckets at the documented thresholds', () {
      const colors = ScoreColors.light;
      expect(colors.forScore(0.0), colors.veryLow);
      expect(colors.forScore(0.19), colors.veryLow);
      expect(colors.forScore(0.20), colors.low);
      expect(colors.forScore(0.39), colors.low);
      expect(colors.forScore(0.40), colors.mid);
      expect(colors.forScore(0.59), colors.mid);
      expect(colors.forScore(0.60), colors.high);
      expect(colors.forScore(0.79), colors.high);
      expect(colors.forScore(0.80), colors.veryHigh);
      expect(colors.forScore(1.0), colors.veryHigh);
    });

    test('lerp interpolates between two ScoreColors instances', () {
      final lerped = ScoreColors.light.lerp(ScoreColors.dark, 0.5);
      expect(lerped, isA<ScoreColors>());
      expect(lerped.low, isNot(equals(ScoreColors.light.low)));
      expect(lerped.veryHigh, isNot(equals(ScoreColors.light.veryHigh)));
    });

    testWidgets('is registered on AppTheme.light', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              final ext = Theme.of(context).extension<ScoreColors>();
              expect(ext, isNotNull);
              expect(ext!.low, ScoreColors.light.low);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('is registered on AppTheme.dark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              final ext = Theme.of(context).extension<ScoreColors>();
              expect(ext, isNotNull);
              expect(ext!.low, ScoreColors.dark.low);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
