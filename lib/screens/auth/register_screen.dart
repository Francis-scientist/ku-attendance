import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/core/utils/validators.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/app_text_field.dart';
import 'package:am_in/widgets/primary_button.dart';

/// Self-registration for students and lecturers. Admins are provisioned
/// out-of-band, so the role selector only offers [UserRole.selfRegisterable].
///
/// The role picked here is written to the profile, but Firestore Security Rules
/// independently reject any attempt to self-register as admin — the client is
/// never the authority on privilege.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _idNumber = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _faculty = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _idNumber.dispose();
    _department.dispose();
    _faculty.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final bool isStudent = _role == UserRole.student;
    final AppUser profile = AppUser(
      uid: '', // assigned server-side from the new Auth credential
      name: _name.text.trim(),
      email: _email.text.trim(),
      role: _role,
      admissionNumber: isStudent ? _idNumber.text.trim() : null,
      staffNumber: isStudent ? null : _idNumber.text.trim(),
      department: _emptyToNull(_department.text),
      faculty: _emptyToNull(_faculty.text),
      phone: _emptyToNull(_phone.text),
    );

    await ref.read(authControllerProvider.notifier).register(
          profile: profile,
          password: _password.text,
        );
    // Success → router redirect routes to the new user's dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(authControllerProvider);
    final bool isLoading = state.isLoading;
    final bool isStudent = _role == UserRole.student;

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppFeedback.showError(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                    Text(
                      'I am a',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: <ButtonSegment<UserRole>>[
                        for (final UserRole r in UserRole.selfRegisterable)
                          ButtonSegment<UserRole>(
                            value: r,
                            label: Text(r.label),
                            icon: Icon(r == UserRole.student
                                ? Icons.school_outlined
                                : Icons.co_present_outlined),
                          ),
                      ],
                      selected: <UserRole>{_role},
                      onSelectionChanged: isLoading
                          ? null
                          : (Set<UserRole> s) =>
                              setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _name,
                      label: 'Full name',
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: (String? v) =>
                          Validators.requiredField(v, field: 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _idNumber,
                      label: isStudent ? 'Admission number' : 'Staff number',
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: isStudent
                          ? Validators.admissionNumber
                          : Validators.staffNumber,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _department,
                      label: 'Department (optional)',
                      prefixIcon: Icons.account_tree_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _faculty,
                      label: 'Faculty / School (optional)',
                      prefixIcon: Icons.apartment_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phone,
                      label: 'Phone (optional)',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscure: true,
                      obscureToggle: true,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirm,
                      label: 'Confirm password',
                      prefixIcon: Icons.lock_outline,
                      obscure: true,
                      obscureToggle: true,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      validator: (String? v) =>
                          Validators.confirmPassword(v, _password.text),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Create account',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: isLoading ? null : () => context.pop(),
                          child: const Text('Sign in'),
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
