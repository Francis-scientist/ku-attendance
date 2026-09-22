import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/providers/auth_providers.dart';

/// A reusable "Sign out" app-bar action shared by every role's interface
/// (admin, lecturer, student), so sign-out behaves identically everywhere.
///
/// It confirms first, then calls [AuthController.signOut] — which is just
/// Firebase Authentication's `signOut()`. It deliberately performs NO
/// navigation: the router's auth redirect detects the signed-out state
/// (`authStateProvider` → null) and returns the user to the login screen, while
/// every `autoDispose` data provider tears its Firestore stream down. This
/// keeps a single source of truth for "where the user may be".
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => _confirmAndSignOut(context, ref),
    );
  }
}
