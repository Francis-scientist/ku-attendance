import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/services/location_service.dart';

/// Returned to the lecturer when a session starts. The [otp] is held only in
/// app memory here — it is written to a locked subcollection students cannot
/// read, never to the session document itself.
class StartedSession {
  final String sessionId;
  final String otp;
  final DateTime expiresAt;

  const StartedSession({
    required this.sessionId,
    required this.otp,
    required this.expiresAt,
  });
}

/// The core attendance engine.
///
/// - Lecturers create/close sessions directly (guarded by Security Rules).
/// - The OTP is generated with a cryptographically secure RNG and stored in
///   `attendanceSessions/{id}/private/otp` (lecturer/admin-readable only).
/// - Students NEVER write attendance directly. Marking goes through the
///   `markAttendance` Cloud Function, which is the sole authority on OTP,
///   geofence, enrollment, duplicates and server time.
class AttendanceRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final LocationService _location;

  AttendanceRepository(this._db, this._functions, this._location);

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection(AppConstants.sessionsCollection);

  // ---------------------------------------------------------------------------
  // Lecturer
  // ---------------------------------------------------------------------------

  /// Creates an active session for [course] at the lecturer's location and
  /// writes a fresh OTP to the locked subcollection.
  Future<StartedSession> startSession({
    required Course course,
    required AppUser lecturer,
    required double latitude,
    required double longitude,
    required double radius,
    required int durationMinutes,
  }) async {
    try {
      final String otp = _generateOtp();
      // Client estimate for the countdown UI; the server clock is authoritative
      // for actual expiry (the Cloud Function recomputes from startedAt).
      final DateTime expiresAt =
          DateTime.now().add(Duration(minutes: durationMinutes));

      final DocumentReference<Map<String, dynamic>> ref = _sessions.doc();
      await ref.set(<String, dynamic>{
        'courseId': course.id,
        'courseCode': course.courseCode,
        'courseName': course.courseName,
        'lecturerId': lecturer.uid,
        'lecturerName': lecturer.name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'durationMinutes': durationMinutes,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'presentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await ref
          .collection(AppConstants.privateSubcollection)
          .doc(AppConstants.otpDocId)
          .set(<String, dynamic>{
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return StartedSession(
        sessionId: ref.id,
        otp: otp,
        expiresAt: expiresAt,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> closeSession(String sessionId) async {
    try {
      await _sessions.doc(sessionId).update(<String, dynamic>{
        'isActive': false,
        'closedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Streams the session's OTP from the locked subcollection. Only the owning
  /// lecturer/admin can read this (enforced by Security Rules), so the lecturer
  /// can re-open the live screen and still read out the code. Students calling
  /// this are denied by rules and simply never see the value.
  Stream<String?> watchOtp(String sessionId) => _sessions
      .doc(sessionId)
      .collection(AppConstants.privateSubcollection)
      .doc(AppConstants.otpDocId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> doc) =>
          doc.data()?['otp'] as String?);

  /// Real-time single session (drives the lecturer's live view + countdown).
  Stream<AttendanceSession?> watchSession(String sessionId) =>
      _sessions.doc(sessionId).snapshots().map(
            (DocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.exists ? AttendanceSession.fromDoc(doc) : null,
          );

  /// Real-time attendance records for a session, newest first. This is the
  /// stream powering the lecturer's live "students marking in" dashboard.
  Stream<List<AttendanceRecord>> watchRecords(String sessionId) => _sessions
      .doc(sessionId)
      .collection(AppConstants.recordsSubcollection)
      .orderBy('markedAt', descending: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(AttendanceRecord.fromDoc).toList());

  /// Sessions for a course, newest first (needs composite index
  /// courseId + createdAt — see firestore.indexes.json). Used for history.
  Stream<List<AttendanceSession>> watchSessionsForCourse(String courseId) =>
      _sessions
          .where('courseId', isEqualTo: courseId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(AttendanceSession.fromDoc).toList());

  /// A lecturer's recent sessions across all their courses (needs composite
  /// index lecturerId + createdAt).
  Stream<List<AttendanceSession>> watchSessionsForLecturer(String lecturerId) =>
      _sessions
          .where('lecturerId', isEqualTo: lecturerId)
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(AttendanceSession.fromDoc).toList());

  // ---------------------------------------------------------------------------
  // Student
  // ---------------------------------------------------------------------------

  /// All currently-active sessions (single-field index on `isActive`). The
  /// student screen filters these down to the courses they're enrolled in.
  /// University-wide active sessions at any instant are few, so this is cheap
  /// and avoids a per-course listener explosion.
  Stream<List<AttendanceSession>> watchActiveSessions() => _sessions
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(AttendanceSession.fromDoc).toList());

  /// The student's own record for a session, if any (confirmation + dedupe UI).
  Stream<AttendanceRecord?> watchOwnRecord(String sessionId, String studentId) =>
      _sessions
          .doc(sessionId)
          .collection(AppConstants.recordsSubcollection)
          .doc(studentId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) =>
              doc.exists ? AttendanceRecord.fromDoc(doc) : null);

  /// The student's full attendance history across all sessions (collection-group
  /// query on `records`; needs a collection-group index studentId + markedAt).
  Stream<List<AttendanceRecord>> watchStudentHistory(String studentId) => _db
      .collectionGroup(AppConstants.recordsSubcollection)
      .where('studentId', isEqualTo: studentId)
      .orderBy('markedAt', descending: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(AttendanceRecord.fromDoc).toList());

  /// Marks attendance via the authoritative Cloud Function.
  ///
  /// Flow: obtain a location fix on-device (throws a friendly [AppException] on
  /// permission/GPS problems) → call the function with the OTP + coordinates →
  /// the server validates everything and writes the record. If offline, the
  /// callable fails immediately (it never queues), so we never falsely report
  /// success.
  Future<void> markAttendance({
    required String sessionId,
    required String otp,
  }) async {
    // 1. Location fix (may throw AppException — surfaced directly to the user).
    final LocationReading reading = await _location.getCurrentReading();

    // 2. Authoritative server-side validation + write.
    try {
      final HttpsCallable callable =
          _functions.httpsCallable(AppConstants.markAttendanceCallable);
      await callable.call<dynamic>(<String, dynamic>{
        'sessionId': sessionId,
        'otp': otp,
        'latitude': reading.latitude,
        'longitude': reading.longitude,
        'accuracy': reading.accuracy,
        'isMocked': reading.isMocked,
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Cryptographically secure N-digit OTP (e.g. "0473"), zero-padded so it is
  /// always exactly [AppConstants.otpLength] digits.
  String _generateOtp() {
    final Random rng = Random.secure();
    final int max = pow(10, AppConstants.otpLength).toInt();
    return rng.nextInt(max).toString().padLeft(AppConstants.otpLength, '0');
  }
}
