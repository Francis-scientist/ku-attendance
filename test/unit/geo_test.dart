import 'package:flutter_test/flutter_test.dart';

import 'package:am_in/core/utils/geo.dart';

/// Geofence maths. This mirrors the Haversine logic the `markAttendance` Cloud
/// Function runs server-side, so these tests guard the shared attendance rule:
/// a student is present only when within `radius` metres of the lecturer.
void main() {
  group('Geo.distanceMeters', () {
    test('is ~0 for identical points', () {
      expect(Geo.distanceMeters(-1.2921, 36.8219, -1.2921, 36.8219),
          closeTo(0, 0.5));
    });

    test('one degree of longitude at the equator is ~111.2 km', () {
      expect(Geo.distanceMeters(0, 0, 0, 1), closeTo(111195, 200));
    });

    test('a small northward step is a few metres', () {
      // ~0.00009 deg latitude ≈ 10 m.
      final double d = Geo.distanceMeters(-1.2921, 36.8219, -1.29201, 36.8219);
      expect(d, closeTo(10, 3));
    });
  });

  group('Geo.isWithinRadius', () {
    test('inside the radius passes', () {
      expect(Geo.isWithinRadius(49, 50), isTrue);
    });

    test('exactly on the boundary passes (<=)', () {
      expect(Geo.isWithinRadius(50, 50), isTrue);
    });

    test('outside the radius fails', () {
      expect(Geo.isWithinRadius(50.1, 50), isFalse);
    });
  });

  group('Geo.isValidCoordinate', () {
    test('rejects the null island (0,0)', () {
      expect(Geo.isValidCoordinate(0, 0), isFalse);
    });

    test('rejects out-of-range values', () {
      expect(Geo.isValidCoordinate(91, 0), isFalse);
      expect(Geo.isValidCoordinate(0, 181), isFalse);
    });

    test('accepts a real coordinate (Nairobi)', () {
      expect(Geo.isValidCoordinate(-1.2921, 36.8219), isTrue);
    });
  });

  group('end-to-end geofence decision (50 m default)', () {
    const double lecLat = -1.29210;
    const double lecLng = 36.82190;
    const double radius = 50;

    test('a student ~10 m away is admitted', () {
      final double d =
          Geo.distanceMeters(lecLat, lecLng, -1.29201, lecLng);
      expect(Geo.isWithinRadius(d, radius), isTrue);
    });

    test('a student ~1.1 km away is rejected', () {
      final double d = Geo.distanceMeters(lecLat, lecLng, -1.28210, lecLng);
      expect(Geo.isWithinRadius(d, radius), isFalse);
    });
  });
}
