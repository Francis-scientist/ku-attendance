/// Central, single source of truth for values that must stay identical across
/// the Flutter app, Firestore documents, and the Cloud Functions backend.
///
/// If a collection name or a default ever changes, it changes here once.
class AppConstants {
  AppConstants._(); // no instances — this is a namespace of constants.

  // ---- University identity ----
  static const String universityName = 'Kenyatta University';
  static const String appName = 'KU Attendance';

  // ---- Firestore collection / document names ----
  static const String usersCollection = 'users';
  static const String coursesCollection = 'courses';
  static const String enrollmentsCollection = 'enrollments';
  static const String sessionsCollection = 'attendanceSessions';
  static const String recordsSubcollection = 'records';
  static const String privateSubcollection = 'private';
  static const String otpDocId = 'otp';

  // ---- Attendance defaults ----
  static const double defaultRadiusMeters = 50;
  static const int otpLength = 4;
  static const int defaultSessionMinutes = 15;
  static const List<int> sessionDurationOptions = <int>[5, 10, 15, 30, 60];
  static const List<int> radiusOptions = <int>[20, 30, 50, 75, 100, 150];

  // ---- Location ----
  /// Reject a fix this imprecise — a huge accuracy circle can mask a student
  /// who is actually outside the geofence.
  static const double maxAcceptableAccuracyMeters = 50;
  static const Duration locationTimeout = Duration(seconds: 15);

  // ---- Cloud Functions ----
  /// MUST match the region the functions are deployed to (see `functions/`).
  /// us-central1 is used because it is always available; move both this value
  /// and the functions deploy region together if you want lower latency.
  static const String functionsRegion = 'us-central1';
  static const String markAttendanceCallable = 'markAttendance';

  // ---- Deterministic document IDs (duplicate prevention) ----
  /// Enrollment ID is derived from course + student so a student can only ever
  /// have ONE enrollment document per course — re-enrolling overwrites rather
  /// than duplicating.
  static String enrollmentId(String courseId, String studentId) =>
      '${courseId}__$studentId';
}
