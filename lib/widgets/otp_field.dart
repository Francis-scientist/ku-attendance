import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:am_in/core/constants/app_constants.dart';

/// A single, large, centred numeric field for entering the session OTP.
///
/// A single field (rather than N separate boxes) keeps focus handling and
/// paste behaviour reliable across keyboards while still reading clearly: the
/// digits are spaced out and constrained to exactly [AppConstants.otpLength].
class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.validator,
    this.enabled = true,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      maxLength: AppConstants.otpLength,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: theme.textTheme.headlineMedium?.copyWith(
        letterSpacing: 18,
        fontWeight: FontWeight.bold,
      ),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AppConstants.otpLength),
      ],
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••',
        labelText: 'Attendance code',
      ),
    );
  }
}
