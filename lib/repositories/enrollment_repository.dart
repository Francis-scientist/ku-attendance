import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/enrollment.dart';

/// All reads/writes against the `enrollments` collection.
///
/// Enrollment IDs are deterministic (`courseId__studentId`) so a student cannot
/// be enrolled twice in the same course.
class EnrollmentRepository {
  final FirebaseFirestore _db;

  EnrollmentRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.enrollmentsCollection);

  /// Active enrollments for a student (isActive filtered in Dart to avoid a
  /// composite index).
  Stream<List<Enrollment>> watchForStudent(String studentId) => _col
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
          .map(Enrollment.fromDoc)
          .where((Enrollment e) => e.isActive)
          .toList());

  /// Enrollments for a course (admin/lecturer views, roster counts).
  Stream<List<Enrollment>> watchForCourse(String courseId) => _col
      .where('courseId', isEqualTo: courseId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
          .map(Enrollment.fromDoc)
          .where((Enrollment e) => e.isActive)
          .toList());

  Future<bool> isEnrolled(String studentId, String courseId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _col.doc(AppConstants.enrollmentId(courseId, studentId)).get();
      return doc.exists && (doc.data()?['isActive'] ?? false) == true;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Admin: enroll a student into a course (idempotent via deterministic ID).
  Future<void> enroll({
    required String studentId,
    required Course course,
  }) async {
    try {
      final Enrollment enrollment = Enrollment(
        id: AppConstants.enrollmentId(course.id, studentId),
        studentId: studentId,
        courseId: course.id,
        courseCode: course.courseCode,
        courseName: course.courseName,
      );
      await _col.doc(enrollment.id).set(<String, dynamic>{
        ...enrollment.toMap(),
        'enrolledAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> setActive({
    required String studentId,
    required String courseId,
    required bool isActive,
  }) async {
    try {
      await _col
          .doc(AppConstants.enrollmentId(courseId, studentId))
          .update(<String, dynamic>{'isActive': isActive});
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
