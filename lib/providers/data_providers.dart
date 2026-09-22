import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/enrollment.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/providers/app_providers.dart';

/// Live data streams for the UI. All are `autoDispose` so a listener that
/// leaves the screen tears its Firestore subscription down, and `family` where
/// they key off an id (course, session, student, lecturer).

// ---- Courses ----
final lecturerCoursesProvider =
    StreamProvider.autoDispose.family<List<Course>, String>(
  (Ref ref, String lecturerUid) =>
      ref.watch(courseRepositoryProvider).watchForLecturer(lecturerUid),
);

final allCoursesProvider = StreamProvider.autoDispose<List<Course>>(
  (Ref ref) => ref.watch(courseRepositoryProvider).watchAll(),
);

/// A single course by id (used when a screen is reached by deep link and the
/// course object wasn't passed via router `extra`).
final courseByIdProvider = FutureProvider.autoDispose.family<Course?, String>(
  (Ref ref, String id) => ref.watch(courseRepositoryProvider).getCourse(id),
);

// ---- Enrollments ----
final studentEnrollmentsProvider =
    StreamProvider.autoDispose.family<List<Enrollment>, String>(
  (Ref ref, String studentId) =>
      ref.watch(enrollmentRepositoryProvider).watchForStudent(studentId),
);

final courseEnrollmentsProvider =
    StreamProvider.autoDispose.family<List<Enrollment>, String>(
  (Ref ref, String courseId) =>
      ref.watch(enrollmentRepositoryProvider).watchForCourse(courseId),
);

// ---- Sessions ----
/// A single live session (countdown + status on the mark/live screens).
final sessionProvider =
    StreamProvider.autoDispose.family<AttendanceSession?, String>(
  (Ref ref, String sessionId) =>
      ref.watch(attendanceRepositoryProvider).watchSession(sessionId),
);

/// Every active session in the university. The student dashboard filters this
/// against the student's enrollments client-side.
final activeSessionsProvider =
    StreamProvider.autoDispose<List<AttendanceSession>>(
  (Ref ref) => ref.watch(attendanceRepositoryProvider).watchActiveSessions(),
);

final courseSessionsProvider =
    StreamProvider.autoDispose.family<List<AttendanceSession>, String>(
  (Ref ref, String courseId) =>
      ref.watch(attendanceRepositoryProvider).watchSessionsForCourse(courseId),
);

final lecturerSessionsProvider =
    StreamProvider.autoDispose.family<List<AttendanceSession>, String>(
  (Ref ref, String lecturerId) => ref
      .watch(attendanceRepositoryProvider)
      .watchSessionsForLecturer(lecturerId),
);

/// The session OTP (lecturer/admin only). Kept separate from [sessionProvider]
/// because it reads the locked subcollection students cannot access.
final sessionOtpProvider =
    StreamProvider.autoDispose.family<String?, String>(
  (Ref ref, String sessionId) =>
      ref.watch(attendanceRepositoryProvider).watchOtp(sessionId),
);

// ---- Records ----
/// Live roster of who has marked in a session (lecturer's real-time view).
final sessionRecordsProvider =
    StreamProvider.autoDispose.family<List<AttendanceRecord>, String>(
  (Ref ref, String sessionId) =>
      ref.watch(attendanceRepositoryProvider).watchRecords(sessionId),
);

/// The student's own record for a session (confirmation state).
final ownRecordProvider = StreamProvider.autoDispose
    .family<AttendanceRecord?, ({String sessionId, String studentId})>(
  (Ref ref, ({String sessionId, String studentId}) args) => ref
      .watch(attendanceRepositoryProvider)
      .watchOwnRecord(args.sessionId, args.studentId),
);

/// A student's full attendance history (collection-group query).
final studentHistoryProvider =
    StreamProvider.autoDispose.family<List<AttendanceRecord>, String>(
  (Ref ref, String studentId) =>
      ref.watch(attendanceRepositoryProvider).watchStudentHistory(studentId),
);

// ---- Admin ----
/// All users of a given role (admin management lists).
final usersByRoleProvider =
    StreamProvider.autoDispose.family<List<AppUser>, UserRole>(
  (Ref ref, UserRole role) =>
      ref.watch(userRepositoryProvider).watchByRole(role),
);
