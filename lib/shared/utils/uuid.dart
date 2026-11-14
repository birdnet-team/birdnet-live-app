// =============================================================================
// UUID — random version 4 identifiers without a package
// =============================================================================
//
// Sessions carry a UUID that is independent of their file name, display
// name, and timestamp id, so an identity survives renames, trims, exports,
// and re-imports on another device. Sixteen bytes from a secure random
// source are all a version 4 UUID needs, so this stays in-house.
// =============================================================================

import 'dart:math';

final Random _secureRandom = Random.secure();

/// Returns a new random version 4 UUID in canonical lowercase form, for
/// example `3f2b1c4e-8d6a-4b7c-9e1f-2a3b4c5d6e7f`.
String generateUuidV4() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
