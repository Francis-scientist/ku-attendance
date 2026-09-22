import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/user_role.dart';

/// All reads/writes against the `users/{uid}` collection.
class UserRepository {
  final FirebaseFirestore _db;

  UserRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.usersCollection);

  /// Real-time profile stream — the source of truth for the current user's
  /// role and details throughout the app.
  Stream<AppUser?> watchUser(String uid) => _col.doc(uid).snapshots().map(
        (DocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.exists ? AppUser.fromDoc(doc) : null,
      );

  Future<AppUser?> getUser(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _col.doc(uid).get();
      return doc.exists ? AppUser.fromDoc(doc) : null;
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Updates editable profile fields, stamping a server `updatedAt`.
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _col.doc(uid).update(<String, dynamic>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Admin: list users by role (e.g. all students, all lecturers).
  Stream<List<AppUser>> watchByRole(UserRole role) => _col
      .where('role', isEqualTo: role.name)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(AppUser.fromDoc).toList());

  /// Admin: enable/disable an account.
  Future<void> setActive(String uid, bool isActive) async {
    try {
      await _col.doc(uid).update(<String, dynamic>{
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
