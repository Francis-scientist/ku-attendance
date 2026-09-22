/// The three user roles in KU Attendance.
///
/// The role is stored on the Firestore `users/{uid}` document as a lowercase
/// string (`role.name`). It decides which dashboard a user sees AND is enforced
/// by Firestore Security Rules — never trust the client UI alone.
enum UserRole {
  student,
  lecturer,
  admin;

  /// Parses a stored string back into a role, defaulting to [student] (the
  /// least-privileged role) if the value is missing or unrecognised.
  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (UserRole r) => r.name == value,
      orElse: () => UserRole.student,
    );
  }

  /// Human-readable label for the UI.
  String get label => switch (this) {
        UserRole.student => 'Student',
        UserRole.lecturer => 'Lecturer',
        UserRole.admin => 'Administrator',
      };

  /// Roles a user is allowed to choose during self-registration.
  /// `admin` is intentionally excluded — admins are provisioned out-of-band.
  static const List<UserRole> selfRegisterable = <UserRole>[
    UserRole.student,
    UserRole.lecturer,
  ];
}
