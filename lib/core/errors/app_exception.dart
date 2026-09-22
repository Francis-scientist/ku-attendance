import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A safe, user-facing error.
///
/// The [message] is always something we are happy to show a user. The optional
/// [code] is kept for logging/debugging only and must never be surfaced raw in
/// the UI (see requirement: "do not expose raw Firebase exception messages").
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException(${code ?? '-'}): $message';
}

/// Translates low-level Firebase/platform errors into [AppException]s with
/// friendly, non-technical messages. This is the ONLY place error strings are
/// mapped, so wording stays consistent everywhere.
class ErrorMapper {
  ErrorMapper._();

  /// Entry point: pass any caught error and get a safe [AppException] back.
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseFunctionsException) return _functions(error);
    if (error is FirebaseException) return _firebase(error);
    return const AppException(
      'Something went wrong. Please try again.',
      code: 'unknown',
    );
  }

  static AppException _auth(FirebaseAuthException e) {
    final String message = switch (e.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' =>
        'This account has been disabled. Contact the administrator.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Please choose a stronger password.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'No internet connection. Please check your network.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled. Contact the administrator.',
      _ => 'Authentication failed. Please try again.',
    };
    return AppException(message, code: e.code);
  }

  static AppException _functions(FirebaseFunctionsException e) {
    // Cloud Functions may return a deliberately safe message in e.message
    // (we control the backend), so we prefer it when present.
    final String message = switch (e.code) {
      'unauthenticated' => 'Please sign in and try again.',
      'permission-denied' =>
        'You are not allowed to perform this action.',
      'not-found' => 'The attendance session could not be found.',
      'failed-precondition' =>
        e.message ?? 'This action cannot be completed right now.',
      'already-exists' =>
        'You have already marked attendance for this session.',
      'deadline-exceeded' ||
      'unavailable' =>
        'No internet connection. Please check your network.',
      'resource-exhausted' =>
        'Too many attempts. Please wait a moment and try again.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
    return AppException(message, code: e.code);
  }

  static AppException _firebase(FirebaseException e) {
    final String message = switch (e.code) {
      'permission-denied' => 'You do not have access to this data.',
      'unavailable' || 'deadline-exceeded' =>
        'No internet connection. Please check your network.',
      'not-found' => 'The requested information was not found.',
      _ => 'Something went wrong. Please try again.',
    };
    return AppException(message, code: e.code);
  }
}
