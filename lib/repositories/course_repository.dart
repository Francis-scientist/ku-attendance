import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/models/course.dart';

/// All reads/writes against the `courses/{courseId}` collection.
class CourseRepository {
  final FirebaseFirestore _db;

  CourseRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.coursesCollection);

  /// Courses assigned to a lecturer. We query only on `lecturerIds`
  /// (arrayContains) and filter `isActive` in Dart, which avoids needing a
  /// composite index for this common lookup.
  Stream<List<Course>> watchForLecturer(String lecturerUid) => _col
      .where('lecturerIds', arrayContains: lecturerUid)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
          .map(Course.fromDoc)
          .where((Course c) => c.isActive)
          .toList());

  /// Admin: every course, ordered by code.
  Stream<List<Course>> watchAll() => _col
      .orderBy('courseCode')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(Course.fromDoc).toList());

  Future<Course?> getCourse(String id) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _col.doc(id).get();
      return doc.exists ? Course.fromDoc(doc) : null;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Admin: create a course; returns the new document ID.
  Future<String> createCourse(Course course) async {
    try {
      final DocumentReference<Map<String, dynamic>> ref = await _col.add(<String, dynamic>{
        ...course.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> updateCourse(String id, Map<String, dynamic> data) async {
    try {
      await _col.doc(id).update(data);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Admin: assign a lecturer to a course (idempotent — `arrayUnion` won't add
  /// a duplicate).
  Future<void> assignLecturer(String courseId, String lecturerUid) async {
    try {
      await _col.doc(courseId).update(<String, dynamic>{
        'lecturerIds': FieldValue.arrayUnion(<String>[lecturerUid]),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Admin: remove a lecturer from a course.
  Future<void> unassignLecturer(String courseId, String lecturerUid) async {
    try {
      await _col.doc(courseId).update(<String, dynamic>{
        'lecturerIds': FieldValue.arrayRemove(<String>[lecturerUid]),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
