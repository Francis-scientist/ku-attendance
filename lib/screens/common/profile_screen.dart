import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/app_text_field.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/primary_button.dart';
import 'package:am_in/widgets/sign_out_button.dart';

/// Shared profile tab for every role: shows the signed-in user's details,
/// allows editing the non-sensitive fields (name, department, faculty, phone)
/// and signs out. Role, email and ID number are read-only — changing those is
/// out of the user's hands (and blocked by Security Rules).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _faculty = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _department.dispose();
    _faculty.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _startEditing(AppUser user) {
    _name.text = user.name;
    _department.text = user.department ?? '';
    _faculty.text = user.faculty ?? '';
    _phone.text = user.phone ?? '';
    setState(() => _editing = true);
  }

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
        user.uid,
        <String, dynamic>{
          'name': _name.text.trim(),
          'department': _emptyToNull(_department.text),
          'faculty': _emptyToNull(_faculty.text),
          'phone': _emptyToNull(_phone.text),
        },
      );
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Profile updated.');
      setState(() => _editing = false);
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const <Widget>[SignOutButton()],
      ),
      body: AsyncValueView<AppUser?>(
        value: userAsync,
        dataBuilder: (AppUser? user) {
          if (user == null) {
            return const Center(child: Text('No profile found.'));
          }
          return _editing ? _buildEditForm(user) : _buildDetails(user);
        },
      ),
    );
  }

  Widget _buildDetails(AppUser user) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  _initials(user.name),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Chip(
                label: Text(user.role.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _InfoTile(
          icon: Icons.badge_outlined,
          label: user.isStudent ? 'Admission number' : 'Staff number',
          value: user.identifier,
        ),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email,
        ),
        _InfoTile(
          icon: Icons.account_tree_outlined,
          label: 'Department',
          value: user.department ?? '—',
        ),
        _InfoTile(
          icon: Icons.apartment_outlined,
          label: 'Faculty / School',
          value: user.faculty ?? '—',
        ),
        _InfoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: user.phone ?? '—',
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onPressed: () => _startEditing(user),
        ),
      ],
    );
  }

  Widget _buildEditForm(AppUser user) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          AppTextField(
            controller: _name,
            label: 'Full name',
            prefixIcon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            enabled: !_saving,
            validator: (String? v) =>
                v == null || v.trim().isEmpty ? 'Name is required.' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _department,
            label: 'Department (optional)',
            prefixIcon: Icons.account_tree_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _faculty,
            label: 'Faculty / School (optional)',
            prefixIcon: Icons.apartment_outlined,
            textCapitalization: TextCapitalization.words,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _phone,
            label: 'Phone (optional)',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            enabled: !_saving,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save changes',
            isLoading: _saving,
            onPressed: () => _save(user),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => setState(() => _editing = false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
