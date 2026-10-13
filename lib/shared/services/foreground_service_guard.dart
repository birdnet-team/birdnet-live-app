// =============================================================================
// Foreground Service Guard - mutual exclusion for the shared Android service
// =============================================================================
//
// ARU (serviceId 512), Survey (256), and background Live Mode or Point Count
// (384) share the single `ForegroundService` in AndroidManifest.xml. Only one
// mode may own it at a time.
//
// Each notification controller must [tryClaim] before `startService` and
// [release] after `stopService` (or when a start attempt fails).

/// The mode currently holding the shared Android foreground service.
enum ForegroundServiceOwner { survey, aru, live, pointCount }

/// Identity-bearing claim used when multiple controllers can share an owner.
class ForegroundServiceLease {
  const ForegroundServiceLease._(this.owner, this._id);

  final ForegroundServiceOwner owner;
  final int _id;

  bool get isCurrent => ForegroundServiceGuard._isCurrent(this);

  void release() => ForegroundServiceGuard._releaseLease(this);
}

/// Process-wide tracker for the shared Android foreground service.
class ForegroundServiceGuard {
  ForegroundServiceGuard._();

  static ForegroundServiceOwner? _owner;
  static int? _leaseId;
  static int _nextLeaseId = 0;

  /// The current owner, or `null` when the foreground service is free.
  static ForegroundServiceOwner? get owner => _owner;

  /// Attempts to claim the foreground service for [owner].
  ///
  /// Returns `true` if [owner] already holds it or the service is free;
  /// returns `false` (without changing ownership) when a different mode owns it.
  static bool tryClaim(ForegroundServiceOwner owner) {
    if (_owner != null && _owner != owner) return false;
    _owner = owner;
    return true;
  }

  /// Claims the service with a unique identity.
  ///
  /// Unlike [tryClaim], this rejects a second claim from the same owner so a
  /// stale asynchronous request cannot affect its replacement.
  static ForegroundServiceLease? tryAcquire(ForegroundServiceOwner owner) {
    if (_owner != null) return null;
    final lease = ForegroundServiceLease._(owner, ++_nextLeaseId);
    _owner = owner;
    _leaseId = lease._id;
    return lease;
  }

  /// Releases the claim if [owner] currently holds it.
  static void release(ForegroundServiceOwner owner) {
    if (_owner == owner) {
      _owner = null;
      _leaseId = null;
    }
  }

  static bool _isCurrent(ForegroundServiceLease lease) =>
      _owner == lease.owner && _leaseId == lease._id;

  static void _releaseLease(ForegroundServiceLease lease) {
    if (!_isCurrent(lease)) return;
    _owner = null;
    _leaseId = null;
  }
}
