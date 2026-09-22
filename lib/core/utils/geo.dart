import 'dart:math';

/// Geographic helpers used on the client for *display and pre-checks only*.
///
/// The authoritative geofence check runs in the `markAttendance` Cloud Function
/// using the same Haversine formula. Never rely on this client-side result to
/// grant attendance — a device can lie about its location.
class Geo {
  Geo._();

  static const double _earthRadiusMetres = 6371000.0;

  /// Great-circle distance between two lat/lng points, in metres.
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMetres * c;
  }

  /// Whether [distance] (metres) is within [radius] (metres).
  static bool isWithinRadius(double distance, double radius) =>
      distance <= radius;

  /// Basic sanity check that coordinates are real (not 0,0 or out of range).
  static bool isValidCoordinate(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat == 0 && lng == 0);

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
