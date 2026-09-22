import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/models/app_user.dart';

/// Owns all Firebase Authentication access plus the tightly-coupled step of
/// creating a user's Firestore profile at registration.
///
/// All thrown errors are mapped to [AppException] so callers never see raw
/// Firebase error text.
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository(this._auth, this._db);

  /// Emits the signed-in [User] (or null) whenever auth state changes. This is
  /// what drives role-based routing and "stay logged in" persistence — Firebase
  /// persists the session automatically.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Creates the Auth credential AND the Firestore profile document.
  ///
  /// The [profile] carries the role (restricted to student/lecturer by the UI
  /// and by Security Rules — never admin) and role-specific fields. The Auth
  /// UID becomes the profile document ID, tying identity and profile together.
  Future<void> register({
    required AppUser profile,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: profile.email.trim(),
        password: password,
      );
      final String uid = credential.user!.uid;

      await _db.collection(AppConstants.usersCollection).doc(uid).set(<String, dynamic>{
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await credential.user!.updateDisplayName(profile.name);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
