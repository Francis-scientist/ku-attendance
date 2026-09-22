import 'package:flutter/material.dart';

import 'package:am_in/core/errors/app_exception.dart';

/// Consistent, non-blocking user feedback. All error surfacing goes through
/// [showErrorSnack] so raw Firebase exceptions are never shown to the user.
class AppFeedback {
  const AppFeedback._();

  static void showError(BuildContext context, Object error) {
    final String message =
        error is AppException ? error.message : ErrorMapper.map(error).message;
    _show(context, message, isError: true);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void _show(BuildContext context, String message,
      {required bool isError}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? scheme.error : null,
        ),
      );
  }
}
