import 'package:cloud_firestore/cloud_firestore.dart';

/// An attendance session started by a lecturer, stored at
/// `attendanceSessions/{sessionId}`.
///
/// SECURITY: the OTP is deliberately NOT a field on this model or document.
/// Enrolled students stream this document to see active sessions in real time,
/// and Firestore rules cannot hide a single field — so the OTP lives in the
/// locked subcollection `attendanceSessions/{id}/private/otp`, readable only by
/// the owning lecturer/admin, and is validated server-side by a Cloud Function.
class AttendanceSession {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String lecturerId;
  final String? lecturerName;
  final double latitude;
  final double longitude;
  final double radius; // metres
  final int durationMinutes;
  final DateTime? startedAt; // server timestamp
  final DateTime? expiresAt; // client estimate for the countdown UI
  final bool isActive;
  final int presentCount;
  final DateTime? createdAt;
  final DateTime? closedAt;

  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.lecturerId,
    this.lecturerName,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.durationMinutes,
    this.startedAt,
    this.expiresAt,
    this.isActive = true,
    this.presentCount = 0,
    this.createdAt,
    this.closedAt,
  });

  /// Whether the countdown has run out, per the *client* clock. This is for UI
  /// only — the Cloud Function re-checks expiry against the server clock.
  bool get isExpiredByClock =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether students should still be offered the "Mark attendance" action.
  bool get isOpen => isActive && !isExpiredByClock;

  /// Time left before the countdown reaches zero (never negative).
  Duration get remaining {
    if (expiresAt == null) return Duration.zero;
    final Duration diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory AttendanceSession.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceSession(
      id: id,
      courseId: (map['courseId'] ?? '') as String,
      courseCode: (map['courseCode'] ?? '') as String,
      courseName: (map['courseName'] ?? '') as String,
      lecturerId: (map['lecturerId'] ?? '') as String,
      lecturerName: map['lecturerName'] as String?,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      radius: _toDouble(map['radius']),
      durationMinutes: (map['durationMinutes'] ?? 0) as int,
      startedAt: _toDate(map['startedAt']),
      expiresAt: _toDate(map['expiresAt']),
      isActive: (map['isActive'] ?? false) as bool,
      presentCount: (map['presentCount'] ?? 0) as int,
      createdAt: _toDate(map['createdAt']),
      closedAt: _toDate(map['closedAt']),
    );
  }

  factory AttendanceSession.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceSession.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  static double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : 0.0;

  static DateTime? _toDate(dynamic value) =>
      value is Timestamp ? value.toDate() : (value is DateTime ? value : null);
}
