import 'package:flutter_test/flutter_test.dart';

import 'package:am_in/core/utils/validators.dart';

/// Validators back every auth/registration form. The OTP validator in
/// particular guards the exact-4-digit contract the Cloud Function also
/// enforces server-side.
void main() {
  group('email', () {
    test('rejects empty and malformed', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
    test('accepts a valid address', () {
      expect(Validators.email('jane.doe@students.ku.ac.ke'), isNull);
    });
  });

  group('password', () {
    test('requires 8+ chars with letters and numbers', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('allletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('passw0rd'), isNull);
    });
  });

  group('confirmPassword', () {
    test('must match the original', () {
      expect(Validators.confirmPassword('passw0rd', 'passw0rd'), isNull);
      expect(Validators.confirmPassword('passw0rd', 'other'), isNotNull);
    });
  });

  group('otp', () {
    test('accepts exactly 4 digits', () {
      expect(Validators.otp('0473'), isNull);
      expect(Validators.otp('0000'), isNull);
    });
    test('rejects wrong length or non-digits', () {
      expect(Validators.otp(''), isNotNull);
      expect(Validators.otp('123'), isNotNull);
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('12a4'), isNotNull);
    });
  });

  group('requiredField', () {
    test('uses the field name in the message', () {
      expect(Validators.requiredField('', field: 'Course code'),
          contains('Course code'));
      expect(Validators.requiredField('x'), isNull);
    });
  });
}
