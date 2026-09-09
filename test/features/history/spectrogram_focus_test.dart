// =============================================================================
// Spectrogram Focus Tests
// =============================================================================
//
// Tapping a detection in a long recording narrows the strip onto the playhead.
// That is both a display choice — show the call, not the ten minutes around
// it — and a performance one, because a tile's decode cost scales with the
// span of audio the visible window covers.
//
// The rule that makes it feel right is "only ever zoom in". These pin it.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_review_screen.dart';

const double _min = 1.0;
const double _max = 60.0;

double? resolve(
  double requested, {
  required double current,
  double total = 3600.0,
}) {
  return SpectrogramFocusRequest(viewSeconds: requested, token: 1).resolve(
    currentViewSeconds: current,
    totalSeconds: total,
    minViewSeconds: _min,
    maxViewSeconds: _max,
  );
}

void main() {
  group('SpectrogramFocusRequest.resolve', () {
    test('narrows a wide view onto the preferred window', () {
      // The case this exists for: an hour-long file opens at 60 s, and one
      // tile then spans minutes of audio.
      expect(resolve(10.0, current: 60.0), 10.0);
    });

    test('leaves an already-narrow view alone', () {
      // The user pinched in to 3 s to study a call; a detection tap must not
      // pull them back out to 10 s.
      expect(resolve(10.0, current: 3.0), isNull);
    });

    test('is a no-op when the view already matches', () {
      expect(resolve(10.0, current: 10.0), isNull);
    });

    test('never proposes a window wider than the recording', () {
      // A 4 s session with a 10 s preference: clamping to the recording makes
      // the request a no-op rather than zooming out past the end.
      expect(resolve(10.0, current: 4.0, total: 4.0), isNull);
      // And when there is room to narrow, the clamp still applies.
      expect(resolve(30.0, current: 20.0, total: 8.0), 8.0);
    });

    test('respects the strip zoom floor', () {
      expect(resolve(0.2, current: 10.0), _min);
    });

    test('respects the strip zoom ceiling', () {
      // A preference above the ceiling can still narrow a wider view, but
      // only down to the ceiling.
      expect(resolve(600.0, current: 3600.0, total: 3600.0), _max);
    });

    test('an unknown duration does not block focusing', () {
      // Duration arrives asynchronously on some platforms; a zero total must
      // not be read as "the recording is 0 s long".
      expect(resolve(10.0, current: 60.0, total: 0.0), 10.0);
    });

    test('a non-positive request is ignored', () {
      expect(resolve(0.0, current: 60.0), isNull);
      expect(resolve(-5.0, current: 60.0), isNull);
    });

    test('the token distinguishes repeat requests', () {
      // Tapping the same detection twice must be two distinct requests, or
      // the strip would ignore the second after the user pinched away.
      const a = SpectrogramFocusRequest(viewSeconds: 10, token: 1);
      const b = SpectrogramFocusRequest(viewSeconds: 10, token: 2);
      expect(a.token, isNot(b.token));
      expect(a.viewSeconds, b.viewSeconds);
    });
  });
}
