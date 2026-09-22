import 'package:cloud_firestore/cloud_firestore.dart';

/// Links a student to a course, stored at
/// `enrollments/{courseId}__{studentId}`.
///
/// The deterministic document ID means a student can hold at most one
/// enrollment per course, so the Cloud Function can verify enrollment with a
/// single cheap `get()` instead of a query.
class Enrollment {
  final String id;
  final String studentId;
  final String courseId;
  final String? courseCode; // denormalised for list rendering
  final String? courseName;
  final bool isActive;
  final DateTime? enrolledAt;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.courseId,
    this.courseCode,
    this.courseName,
    this.isActive = true,
    this.enrolledAt,
  });

  factory Enrollment.fromMap(String id, Map<String, dynamic> map) {
    return Enrollment(
      id: id,
      studentId: (map['studentId'] ?? '') as String,
      courseId: (map['courseId'] ?? '') as String,
      courseCode: map['courseCode'] as String?,
      courseName: map['courseName'] as String?,
      isActive: (map['isActive'] ?? true) as bool,
      enrolledAt: _toDate(map['enrolledAt']),
    );
  }

  factory Enrollment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Enrollment.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'studentId': studentId,
        'courseId': courseId,
        if (courseCode != null) 'courseCode': courseCode,
        if (courseName != null) 'courseName': courseName,
        'isActive': isActive,
      };

  static DateTime? _toDate(dynamic value) =>
      value is Timestamp ? value.toDate() : (value is DateTime ? value : null);
}
