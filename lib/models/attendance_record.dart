import 'package:cloud_firestore/cloud_firestore.dart';

/// A single student's attendance for one session, stored at
/// `attendanceSessions/{sessionId}/records/{studentId}`.
///
/// The document ID IS the student's UID, which makes double-marking
/// structurally impossible: a second write targets the same document. These
/// records are created only by the `markAttendance` Cloud Function (clients
/// cannot write them), so every field is server-authored and trustworthy.
class AttendanceRecord {
  final String studentId; // == document ID
  final String studentName;
  final String? admissionNumber;
  final String courseId;
  final String? courseCode; // denormalised from the session for display
  final String? courseName; // denormalised from the session for display
  final String sessionId;
  final DateTime? markedAt; // server timestamp
  final double? latitude;
  final double? longitude;
  final double? distanceFromLecturer; // metres, computed server-side
  final String status; // 'present'

  const AttendanceRecord({
    required this.studentId,
    required this.studentName,
    this.admissionNumber,
    required this.courseId,
    this.courseCode,
    this.courseName,
    required this.sessionId,
    this.markedAt,
    this.latitude,
    this.longitude,
    this.distanceFromLecturer,
    this.status = 'present',
  });

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      studentId: id,
      studentName: (map['studentName'] ?? '') as String,
      admissionNumber: map['admissionNumber'] as String?,
      courseId: (map['courseId'] ?? '') as String,
      courseCode: map['courseCode'] as String?,
      courseName: map['courseName'] as String?,
      sessionId: (map['sessionId'] ?? '') as String,
      markedAt: _toDate(map['markedAt']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      distanceFromLecturer: (map['distanceFromLecturer'] as num?)?.toDouble(),
      status: (map['status'] ?? 'present') as String,
    );
  }

  factory AttendanceRecord.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceRecord.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  static DateTime? _toDate(dynamic value) =>
      value is Timestamp ? value.toDate() : (value is DateTime ? value : null);
}
