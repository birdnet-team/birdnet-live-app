// =============================================================================
// Altitude Reference - Device-reported height reference surfaces
// =============================================================================

/// Reference surface for a device-reported altitude.
enum AltitudeReference {
  /// Height above the WGS84 reference ellipsoid.
  wgs84Ellipsoid,

  /// Height above approximate mean sea level.
  meanSeaLevel,

  /// The platform did not identify the reference surface.
  unknown;

  static AltitudeReference? fromName(String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return unknown;
  }
}
