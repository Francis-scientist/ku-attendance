import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/repositories/attendance_repository.dart';
import 'package:am_in/repositories/auth_repository.dart';
import 'package:am_in/repositories/course_repository.dart';
import 'package:am_in/repositories/enrollment_repository.dart';
import 'package:am_in/repositories/user_repository.dart';
import 'package:am_in/services/connectivity_service.dart';
import 'package:am_in/services/location_service.dart';

/// Dependency-injection wiring. Every Firebase instance, service and repository
/// is exposed as a provider so screens/tests can read (or override) them
/// without `.instance` singletons scattered through the UI.

// ---- Firebase SDK instances ----
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (Ref ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (Ref ref) => FirebaseFirestore.instance,
);

final functionsProvider = Provider<FirebaseFunctions>(
  (Ref ref) =>
      FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion),
);

// ---- Device services ----
final locationServiceProvider = Provider<LocationService>(
  (Ref ref) => LocationService(),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (Ref ref) => ConnectivityService(),
);

// ---- Repositories ----
final authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => UserRepository(ref.watch(firestoreProvider)),
);

final courseRepositoryProvider = Provider<CourseRepository>(
  (Ref ref) => CourseRepository(ref.watch(firestoreProvider)),
);

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (Ref ref) => EnrollmentRepository(ref.watch(firestoreProvider)),
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (Ref ref) => AttendanceRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
    ref.watch(locationServiceProvider),
  ),
);
