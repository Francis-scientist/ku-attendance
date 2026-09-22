import 'package:flutter_test/flutter_test.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/user_role.dart';

/// Role parsing and session open/expiry logic — the two pieces of model
/// behaviour the UI and router depend on.
void main() {
  group('UserRole.fromString', () {
    test('parses known roles', () {
      expect(UserRole.fromString('student'), UserRole.student);
      expect(UserRole.fromString('lecturer'), UserRole.lecturer);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('defaults to student for unknown/null (least privilege)', () {
      expect(UserRole.fromString(null), UserRole.student);
      expect(UserRole.fromString('superuser'), UserRole.student);
      expect(UserRole.fromString(''), UserRole.student);
    });

    test('admin is not self-registerable', () {
      expect(UserRole.selfRegisterable, isNot(contains(UserRole.admin)));
      expect(UserRole.selfRegisterable,
          containsAll(<UserRole>[UserRole.student, UserRole.lecturer]));
    });
  });

  group('AppUser role getters', () {
    test('reflect the assigned role', () {
      const AppUser u = AppUser(
        uid: 'x',
        name: 'Jane Doe',
        email: 'j@ku.ac.ke',
        role: UserRole.lecturer,
      );
      expect(u.isLecturer, isTrue);
      expect(u.isStudent, isFalse);
      expect(u.isAdmin, isFalse);
      expect(u.firstName, 'Jane');
    });
  });

  group('AttendanceSession open/expiry', () {
    AttendanceSession sessionExpiring(Duration fromNow, {bool active = true}) {
      return AttendanceSession(
        id: 's',
        courseId: 'c',
        courseCode: 'SCO 209',
        courseName: 'Computer Organization',
        lecturerId: 'l',
        latitude: -1.29,
        longitude: 36.82,
        radius: 50,
        durationMinutes: 15,
        expiresAt: DateTime.now().add(fromNow),
        isActive: active,
      );
    }

    test('is open when active and not yet expired', () {
      expect(sessionExpiring(const Duration(minutes: 5)).isOpen, isTrue);
    });

    test('is closed once the clock passes expiry', () {
      expect(sessionExpiring(const Duration(seconds: -1)).isExpiredByClock,
          isTrue);
      expect(sessionExpiring(const Duration(seconds: -1)).isOpen, isFalse);
    });

    test('is closed when deactivated even if not expired', () {
      expect(
          sessionExpiring(const Duration(minutes: 5), active: false).isOpen,
          isFalse);
    });

    test('remaining is never negative', () {
      expect(sessionExpiring(const Duration(seconds: -30)).remaining,
          Duration.zero);
    });
  });
}
