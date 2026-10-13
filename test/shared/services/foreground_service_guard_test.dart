import 'package:birdnet_live/shared/services/foreground_service_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    final owner = ForegroundServiceGuard.owner;
    if (owner != null) ForegroundServiceGuard.release(owner);
  });

  test('lease identity prevents a stale same-mode release', () {
    final first = ForegroundServiceGuard.tryAcquire(
      ForegroundServiceOwner.live,
    );

    expect(first, isNotNull);
    expect(
      ForegroundServiceGuard.tryAcquire(ForegroundServiceOwner.live),
      isNull,
    );

    first!.release();
    final replacement = ForegroundServiceGuard.tryAcquire(
      ForegroundServiceOwner.live,
    );
    expect(replacement, isNotNull);

    first.release();
    expect(replacement!.isCurrent, isTrue);
    expect(ForegroundServiceGuard.owner, ForegroundServiceOwner.live);
  });
}
