import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';

/// A switch that enables or disables a user account via the user repository.
///
/// Disabling a user flips `isActive` to false; the router then bounces them to
/// the login screen and the security rules reject their writes.
class AccountActiveSwitch extends ConsumerStatefulWidget {
  const AccountActiveSwitch({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<AccountActiveSwitch> createState() =>
      _AccountActiveSwitchState();
}

class _AccountActiveSwitchState extends ConsumerState<AccountActiveSwitch> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(userRepositoryProvider).setActive(widget.user.uid, value);
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          value ? 'Account enabled.' : 'Account disabled.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Account active'),
      subtitle: Text(widget.user.isActive
          ? 'The user can sign in and use the app.'
          : 'The user is blocked from signing in.'),
      value: widget.user.isActive,
      onChanged: _busy ? null : _toggle,
    );
  }
}
