// =============================================================================
// AlertThrottler Tests
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/survey/alert_throttler.dart';
import 'package:birdnet_live/features/survey/survey_alert_engine.dart';

/// Mutable clock for deterministic time control in tests.
class _FakeClock {
  _FakeClock(this._t);
  DateTime _t;
  DateTime now() => _t;
  void advance(Duration d) => _t = _t.add(d);
}

AlertCandidate _candidate({
  String name = 'Turdus merula',
  AlertReason reason = AlertReason.firstInSession,
}) {
  return AlertCandidate(
    scientificName: name,
    commonName: name,
    confidence: 0.8,
    timestamp: DateTime(2025, 6, 15, 10, 0),
    reason: reason,
  );
}

void main() {
  final start = DateTime(2025, 6, 15, 10, 0);

  AlertThrottler makeThrottler({
    required _FakeClock clock,
    Duration grace = const Duration(seconds: 60),
    Duration interval = const Duration(seconds: 15),
    int maxPerMinute = 3,
    bool coalesce = true,
    Set<AlertReason> bypass = const {AlertReason.rare, AlertReason.watchlist},
  }) {
    return AlertThrottler(
      surveyStart: start,
      startupGrace: grace,
      minInterval: interval,
      maxPerMinute: maxPerMinute,
      coalesce: coalesce,
      bypassReasons: bypass,
      now: clock.now,
    );
  }

  group('startup grace', () {
    test('suppresses non-bypassed reasons during grace window', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(clock: clock);

      // 5 first-in-session alerts in the first minute → all suppressed.
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 5));
        expect(t.admit(_candidate(name: 'sp_$i')), isA<Suppress>());
      }
      expect(t.tick(), isNull);
    });

    test('allows non-bypassed reasons after grace expires', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: const Duration(seconds: 60),
        interval: Duration.zero,
      );

      clock.advance(const Duration(seconds: 60));
      expect(t.admit(_candidate()), isA<DeliverNow>());
    });

    test('rare bypasses grace', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(clock: clock);
      clock.advance(const Duration(seconds: 5));
      expect(t.admit(_candidate(reason: AlertReason.rare)), isA<DeliverNow>());
    });

    test('watchlist bypasses grace', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(clock: clock);
      clock.advance(const Duration(seconds: 5));
      expect(
        t.admit(_candidate(reason: AlertReason.watchlist)),
        isA<DeliverNow>(),
      );
    });
  });

  group('rate cap with coalescing', () {
    test('first 3 of 10 burst are delivered, rest coalesced into summary', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: Duration.zero,
        maxPerMinute: 3,
      );

      var delivered = 0;
      var coalesced = 0;
      for (var i = 0; i < 10; i++) {
        final decision = t.admit(_candidate(name: 'sp_$i'));
        if (decision is DeliverNow) delivered++;
        if (decision is Coalesce) coalesced++;
      }
      expect(delivered, 3);
      expect(coalesced, 7);

      // Within the same instant, the queue can't flush yet (rate is full
      // and the grace-based queue-age trigger has not fired).
      // queue size 7 >= maxQueueSize (5) → flushes immediately.
      final summary = t.tick();
      expect(summary, isNotNull);
      expect(summary!.count, 7);
    });

    test('coalesce=false drops over-cap alerts entirely', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: Duration.zero,
        maxPerMinute: 1,
        coalesce: false,
      );

      expect(t.admit(_candidate(name: 'a')), isA<DeliverNow>());
      expect(t.admit(_candidate(name: 'b')), isA<Suppress>());
      expect(t.tick(), isNull);
    });

    test('rate window is sliding (60 s)', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: Duration.zero,
        maxPerMinute: 2,
      );
      expect(t.admit(_candidate(name: 'a')), isA<DeliverNow>());
      clock.advance(const Duration(seconds: 5));
      expect(t.admit(_candidate(name: 'b')), isA<DeliverNow>());
      clock.advance(const Duration(seconds: 5));
      expect(t.admit(_candidate(name: 'c')), isA<Coalesce>());

      // After 60 s elapsed since the first delivery, the window slides
      // and a slot frees up.
      clock.advance(const Duration(seconds: 51));
      // tick can now deliver the queued one.
      final summary = t.tick();
      expect(summary, isNotNull);
      expect(summary!.count, 1);
    });

    test('maxPerMinute=0 means unlimited', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: Duration.zero,
        maxPerMinute: 0,
      );
      for (var i = 0; i < 50; i++) {
        expect(t.admit(_candidate(name: 'sp_$i')), isA<DeliverNow>());
      }
    });
  });

  group('min interval', () {
    test('coalesces alerts faster than the interval, flushes after wait', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: const Duration(seconds: 15),
        maxPerMinute: 10,
      );
      expect(t.admit(_candidate(name: 'a')), isA<DeliverNow>());
      clock.advance(const Duration(seconds: 5));
      expect(t.admit(_candidate(name: 'b')), isA<Coalesce>());

      // Not yet 15 s since last delivery → tick returns null.
      expect(t.tick(), isNull);
      clock.advance(const Duration(seconds: 11));
      final summary = t.tick();
      expect(summary, isNotNull);
      expect(summary!.count, 1);
    });
  });

  group('tick semantics', () {
    test('returns null when queue empty', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(clock: clock);
      expect(t.tick(), isNull);
      expect(t.tick(force: true), isNull);
    });

    test('force flushes regardless of timing', () {
      final clock = _FakeClock(start);
      final t = makeThrottler(
        clock: clock,
        grace: Duration.zero,
        interval: const Duration(hours: 1), // unreachable normally
        maxPerMinute: 0,
      );
      expect(t.admit(_candidate(name: 'a')), isA<DeliverNow>());
      clock.advance(const Duration(seconds: 1));
      expect(t.admit(_candidate(name: 'b')), isA<Coalesce>());
      expect(t.tick(), isNull);
      final summary = t.tick(force: true);
      expect(summary, isNotNull);
      expect(summary!.count, 1);
    });

    test('queue-age trigger flushes after maxQueueAge', () {
      final clock = _FakeClock(start);
      final t = AlertThrottler(
        surveyStart: start,
        startupGrace: Duration.zero,
        minInterval: const Duration(seconds: 60),
        maxPerMinute: 1,
        coalesce: true,
        bypassReasons: const {},
        now: clock.now,
        maxQueueAge: const Duration(seconds: 30),
        maxQueueSize: 100,
      );
      expect(t.admit(_candidate(name: 'a')), isA<DeliverNow>());
      clock.advance(const Duration(seconds: 1));
      expect(t.admit(_candidate(name: 'b')), isA<Coalesce>());

      // Less than 30 s queued → no flush yet.
      clock.advance(const Duration(seconds: 20));
      expect(t.tick(), isNull);

      // Past maxQueueAge → flushes.
      clock.advance(const Duration(seconds: 11));
      final summary = t.tick();
      expect(summary, isNotNull);
      expect(summary!.count, 1);
    });
  });

  group('SummaryAlert.primaryReason', () {
    test('picks the most important reason in the queue', () {
      final s = SummaryAlert(
        alerts: [
          _candidate(name: 'a', reason: AlertReason.firstInSession),
          _candidate(name: 'b', reason: AlertReason.firstEver),
          _candidate(name: 'c', reason: AlertReason.rare),
          _candidate(name: 'd', reason: AlertReason.watchlist),
        ],
      );
      expect(s.primaryReason, AlertReason.rare);
    });
  });
}
