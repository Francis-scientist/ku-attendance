import '../constants/app_constants.dart';

/// Reusable form-field validators. Each returns `null` when valid, or a
/// user-facing error message string when invalid — the shape Flutter's
/// [TextFormField.validator] expects.
class Validators {
  Validators._();

  static String? requiredField(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final RegExp re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use letters and numbers.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? admissionNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Admission number is required.';
    }
    // Kept permissive on purpose (formats vary, e.g. "CS001/2024").
    if (value.trim().length < 3) return 'Enter a valid admission number.';
    return null;
  }

  static String? staffNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Staff number is required.';
    }
    if (value.trim().length < 3) return 'Enter a valid staff number.';
    return null;
  }

  /// Validates the exactly-N-digit OTP (N = [AppConstantsRef.otpLength]).
  static String? otp(String? value) {
    final int len = AppConstants.otpLength;
    if (value == null || value.isEmpty) return 'Enter the $len-digit code.';
    if (!RegExp('^\\d{$len}\$').hasMatch(value)) {
      return 'The code must be exactly $len digits.';
    }
    return null;
  }
}
