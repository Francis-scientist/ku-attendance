import 'package:geolocator/geolocator.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

/// The result of a successful location fix.
class LocationReading {
  final double latitude;
  final double longitude;
  final double accuracy; // metres
  final bool isMocked;

  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
  });
}

/// Wraps the platform location APIs (via `geolocator`) with the permission and
/// error handling KU Attendance needs.
///
/// Location permission is only ever requested at the moment it is needed
/// (starting a session, or marking attendance), never at app launch — that is
/// both better UX and required for Play Store review.
///
/// Every failure surfaces as an [AppException] with a clear, safe message.
class LocationService {
  /// Obtains a high-accuracy fix, or throws an [AppException] describing why it
  /// could not (services off, permission denied, timeout, low accuracy…).
  Future<LocationReading> getCurrentReading() async {
    // 1. Are location services (GPS) switched on at all?
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppException(
        'Location services are off. Please enable GPS and try again.',
        code: 'location-services-disabled',
      );
    }

    // 2. Do we have permission? Request it if not decided yet.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AppException(
        'Location permission is required to mark attendance.',
        code: 'location-permission-denied',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        'Location permission is permanently denied. Enable it in Settings.',
        code: 'location-permission-denied-forever',
      );
    }

    // 3. Get an actual fix, with a timeout so we never hang forever.
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: AppConstants.locationTimeout,
        ),
      );

      // 4. Reject a fix too imprecise to trust for a 50 m geofence.
      if (position.accuracy > AppConstants.maxAcceptableAccuracyMeters) {
        throw AppException(
          'Location is not accurate enough (±${position.accuracy.round()} m). '
          'Move to an open area and try again.',
          code: 'location-low-accuracy',
        );
      }

      return LocationReading(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMocked: position.isMocked,
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Could not get your location. Please try again.',
        code: 'location-unavailable',
      );
    }
  }
}
