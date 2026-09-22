import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/screens/admin/admin_home.dart';
import 'package:am_in/screens/auth/forgot_password_screen.dart';
import 'package:am_in/screens/auth/login_screen.dart';
import 'package:am_in/screens/auth/register_screen.dart';
import 'package:am_in/screens/common/splash_screen.dart';
import 'package:am_in/screens/lecturer/lecturer_home.dart';
import 'package:am_in/screens/lecturer/live_attendance_screen.dart';
import 'package:am_in/screens/lecturer/start_attendance_screen.dart';
import 'package:am_in/screens/student/mark_attendance_screen.dart';
import 'package:am_in/screens/student/student_home.dart';

/// Named route paths. Kept as constants so screens navigate without magic
/// strings (e.g. `context.go(AppRoutes.login)`).
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String student = '/student';
  static const String markAttendance = '/student/mark'; // + /:sessionId

  static const String lecturer = '/lecturer';
  static const String startAttendance = '/lecturer/start'; // + /:courseId
  static const String liveAttendance = '/lecturer/live'; // + /:sessionId

  static const String admin = '/admin';
}

/// The app router. Auth + role routing is entirely redirect-driven so there is
/// exactly one place that decides where a user may be:
///
/// 1. Auth/profile still resolving  → splash.
/// 2. Logged out                    → login (auth screens allowed).
/// 3. Logged in                     → their role's home; role guard keeps each
///    role inside its own section.
final routerProvider = Provider<GoRouter>((Ref ref) {
  // A Listenable that pings go_router to re-run `redirect` whenever the
  // signed-in profile changes (login, logout, role/profile update).
  final _RouterRefresh refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<User?> authState = ref.read(authStateProvider);
      final String loc = state.matchedLocation;
      final bool onAuthScreen = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;
      final bool onSplash = loc == AppRoutes.splash;

      // 1a. Firebase auth state still resolving.
      if (authState.isLoading || !authState.hasValue) {
        return onSplash ? null : AppRoutes.splash;
      }

      final User? user = authState.value;

      // 2. Logged out — only auth screens are reachable.
      if (user == null) {
        return onAuthScreen ? null : AppRoutes.login;
      }

      // 1b. Logged in but the Firestore profile (role) is still loading.
      final AsyncValue<AppUser?> profileAsync = ref.read(currentUserProvider);
      if (profileAsync.isLoading) {
        return onSplash ? null : AppRoutes.splash;
      }

      final AppUser? profile = profileAsync.value;

      // Edge case: authenticated but no/disabled profile doc. Hold on login
      // (the account can't be routed without a role).
      if (profile == null || !profile.isActive) {
        return onAuthScreen ? null : AppRoutes.login;
      }

      // 3. Route by role.
      final String home = _homeFor(profile.role);
      final String section = _sectionFor(profile.role);

      if (onAuthScreen || onSplash) return home;

      // Role guard: a user may only be inside their own section.
      if (!loc.startsWith(section)) return home;

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),

      // ---- Student ----
      GoRoute(
        path: AppRoutes.student,
        builder: (_, _) => const StudentHome(),
      ),
      GoRoute(
        path: '${AppRoutes.markAttendance}/:sessionId',
        builder: (BuildContext context, GoRouterState state) =>
            MarkAttendanceScreen(
          sessionId: state.pathParameters['sessionId']!,
          session: state.extra as AttendanceSession?,
        ),
      ),

      // ---- Lecturer ----
      GoRoute(
        path: AppRoutes.lecturer,
        builder: (_, _) => const LecturerHome(),
      ),
      GoRoute(
        path: '${AppRoutes.startAttendance}/:courseId',
        builder: (BuildContext context, GoRouterState state) =>
            StartAttendanceScreen(
          courseId: state.pathParameters['courseId']!,
          course: state.extra as Course?,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.liveAttendance}/:sessionId',
        builder: (BuildContext context, GoRouterState state) =>
            LiveAttendanceScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),

      // ---- Admin ----
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, _) => const AdminHome(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Page not found:\n${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
});

String _homeFor(UserRole role) => switch (role) {
      UserRole.student => AppRoutes.student,
      UserRole.lecturer => AppRoutes.lecturer,
      UserRole.admin => AppRoutes.admin,
    };

String _sectionFor(UserRole role) => switch (role) {
      UserRole.student => AppRoutes.student,
      UserRole.lecturer => AppRoutes.lecturer,
      UserRole.admin => AppRoutes.admin,
    };

/// Bridges Riverpod → go_router: notifies the router to re-evaluate redirects
/// whenever the auth/profile state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<AppUser?>>(
      currentUserProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
