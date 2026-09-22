import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/core/theme/app_colors.dart';
import 'package:am_in/core/utils/validators.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/routes/app_router.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/app_text_field.dart';
import 'package:am_in/widgets/primary_button.dart';

/// Email + password sign-in. On success the router's redirect takes over and
/// routes the user to their role's home — this screen never navigates by role
/// itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
    // Success → router redirect handles navigation. Errors surface via listen.
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(authControllerProvider);
    final bool isLoading = state.isLoading;

    // Surface auth errors as a snackbar without exposing raw exceptions.
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppFeedback.showError(context, next.error!);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 24),
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.how_to_reg,
                          size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to KU Attendance',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      hint: 'you@students.ku.ac.ke',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscure: true,
                      obscureToggle: true,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      validator: (String? v) =>
                          Validators.requiredField(v, field: 'Password'),
                      onSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.forgotPassword),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Sign in',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.push(AppRoutes.register),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
