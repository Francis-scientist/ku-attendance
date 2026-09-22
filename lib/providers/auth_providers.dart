import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/providers/app_providers.dart';

/// Raw Firebase auth state (signed-in `User` or null). This resolves quickly
/// on startup and tells us *whether* someone is logged in.
final authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's Firestore profile (`AppUser`), streamed live so a role
/// or profile change reflects immediately. Emits null when logged out.
///
/// This is the single source of truth for role-based routing. While
/// [authStateProvider] is still resolving we surface loading (not a spurious
/// "logged out") so the router can hold on the splash screen.
final currentUserProvider = StreamProvider<AppUser?>((Ref ref) {
  final AsyncValue<User?> authState = ref.watch(authStateProvider);

  return authState.when(
    data: (User? user) {
      if (user == null) return Stream<AppUser?>.value(null);
      return ref.watch(userRepositoryProvider).watchUser(user.uid);
    },
    // Propagate loading/error as an empty stream; the router reads
    // authStateProvider directly for those states.
    loading: () => const Stream<AppUser?>.empty(),
    error: (_, _) => Stream<AppUser?>.value(null),
  );
});

/// Drives the sign-in / register / reset / sign-out actions and exposes their
/// loading + error state to the forms via a plain `AsyncValue<void>`.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _ref.read(authRepositoryProvider).signIn(
          email: email,
          password: password,
        ));
  }

  Future<bool> register({required AppUser profile, required String password}) {
    return _run(() => _ref.read(authRepositoryProvider).register(
          profile: profile,
          password: password,
        ));
  }

  Future<bool> sendPasswordReset(String email) {
    return _run(() => _ref.read(authRepositoryProvider).sendPasswordReset(email));
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _ref.read(authRepositoryProvider).signOut(),
    );
  }

  /// Runs [action], tracking loading/error. Returns true on success so callers
  /// can navigate only when the action actually succeeded.
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard(action);
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (Ref ref) => AuthController(ref),
);
