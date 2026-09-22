import 'package:cloud_firestore/cloud_firestore.dart';

/// A university course/unit, stored at `courses/{courseId}`.
///
/// Design note: students enrolled in a course are tracked in the separate
/// `enrollments` collection rather than an array on the course. Arrays that
/// grow without bound (thousands of students) are a Firestore anti-pattern —
/// they blow past the 1 MiB document limit and force a full rewrite on every
/// change. Lecturers ([lecturerIds]) are few, so an array is fine there and
/// enables `arrayContains` queries.
class Course {
  final String id;
  final String courseCode; // e.g. "SCO 209"
  final String courseName; // e.g. "Computer Organization"
  final String? department;
  final String? faculty;
  final List<String> lecturerIds;
  final bool isActive;
  final DateTime? createdAt;

  const Course({
    required this.id,
    required this.courseCode,
    required this.courseName,
    this.department,
    this.faculty,
    this.lecturerIds = const <String>[],
    this.isActive = true,
    this.createdAt,
  });

  String get display => '$courseCode — $courseName';

  bool hasLecturer(String uid) => lecturerIds.contains(uid);

  factory Course.fromMap(String id, Map<String, dynamic> map) {
    return Course(
      id: id,
      courseCode: (map['courseCode'] ?? '') as String,
      courseName: (map['courseName'] ?? '') as String,
      department: map['department'] as String?,
      faculty: map['faculty'] as String?,
      lecturerIds: (map['lecturerIds'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      isActive: (map['isActive'] ?? true) as bool,
      createdAt: _toDate(map['createdAt']),
    );
  }

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Course.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'courseCode': courseCode,
        'courseName': courseName,
        if (department != null) 'department': department,
        if (faculty != null) 'faculty': faculty,
        'lecturerIds': lecturerIds,
        'isActive': isActive,
      };

  Course copyWith({
    String? courseCode,
    String? courseName,
    String? department,
    String? faculty,
    List<String>? lecturerIds,
    bool? isActive,
  }) {
    return Course(
      id: id,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
      lecturerIds: lecturerIds ?? this.lecturerIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  static DateTime? _toDate(dynamic value) =>
      value is Timestamp ? value.toDate() : (value is DateTime ? value : null);
}
