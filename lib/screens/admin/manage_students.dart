import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/enrollment.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/account_active_switch.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Admin: browse students, enable/disable accounts, and manage each student's
/// course enrolments.
class ManageStudents extends ConsumerStatefulWidget {
  const ManageStudents({super.key});

  @override
  ConsumerState<ManageStudents> createState() => _ManageStudentsState();
}

class _ManageStudentsState extends ConsumerState<ManageStudents> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppUser>> studentsAsync =
        ref.watch(usersByRoleProvider(UserRole.student));

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              hintText: 'Search name or admission no.',
              leading: const Icon(Icons.search),
              onChanged: (String v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<AppUser>>(
              value: studentsAsync,
              onRetry: () =>
                  ref.invalidate(usersByRoleProvider(UserRole.student)),
              emptyBuilder: () => const EmptyView(
                icon: Icons.school_outlined,
                title: 'No students yet',
                subtitle: 'Students who register will appear here.',
              ),
              dataBuilder: (List<AppUser> students) {
                final List<AppUser> filtered = _filter(students);
                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle: 'Try a different name or admission number.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int i) =>
                      _StudentTile(student: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AppUser> _filter(List<AppUser> users) {
    if (_query.isEmpty) return users;
    return users.where((AppUser u) {
      return u.name.toLowerCase().contains(_query) ||
          (u.admissionNumber ?? '').toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
    }).toList();
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            student.firstName.isNotEmpty
                ? student.firstName[0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(student.name),
        subtitle: Text(student.admissionNumber ?? student.email),
        trailing: student.isActive
            ? StatusChip.positive('Active')
            : StatusChip.negative('Disabled'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _StudentSheet(student: student),
        ),
      ),
    );
  }
}

/// Detail sheet for one student: toggle their account and manage enrolments.
class _StudentSheet extends ConsumerWidget {
  const _StudentSheet({required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Enrollment>> enrollmentsAsync =
        ref.watch(studentEnrollmentsProvider(student.uid));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            Text(student.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(student.email,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (student.admissionNumber != null) ...<Widget>[
              const SizedBox(height: 2),
              Text('Adm: ${student.admissionNumber}',
                  style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            AccountActiveSwitch(user: student),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Enrolled courses',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _enroll(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Enroll'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            enrollmentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) =>
                  const Text('Could not load this student\'s courses.'),
              data: (List<Enrollment> enrollments) {
                if (enrollments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Not enrolled in any course yet.'),
                  );
                }
                return Column(
                  children: enrollments
                      .map((Enrollment e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(e.courseCode ?? e.courseId),
                            subtitle: Text(e.courseName ?? ''),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.remove_circle_outline),
                              color: theme.colorScheme.error,
                              onPressed: () =>
                                  _unenroll(context, ref, e),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final List<Course>? courses =
        ref.read(allCoursesProvider).valueOrNull;
    if (courses == null || courses.isEmpty) {
      AppFeedback.showInfo(context, 'Create a course first.');
      return;
    }
    final List<Enrollment> current =
        ref.read(studentEnrollmentsProvider(student.uid)).valueOrNull ??
            <Enrollment>[];
    final Set<String> enrolledIds =
        current.map((Enrollment e) => e.courseId).toSet();
    final List<Course> available = courses
        .where((Course c) => c.isActive && !enrolledIds.contains(c.id))
        .toList();

    if (available.isEmpty) {
      AppFeedback.showInfo(
          context, 'This student is already in every active course.');
      return;
    }

    final Course? chosen = await showModalBottomSheet<Course>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: available
            .map((Course c) => ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(c.courseCode),
                  subtitle: Text(c.courseName),
                  onTap: () => Navigator.pop(context, c),
                ))
            .toList(),
      ),
    );
    if (chosen == null) return;

    try {
      await ref
          .read(enrollmentRepositoryProvider)
          .enroll(studentId: student.uid, course: chosen);
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Enrolled in ${chosen.courseCode}.');
      }
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _unenroll(
      BuildContext context, WidgetRef ref, Enrollment e) async {
    try {
      await ref.read(enrollmentRepositoryProvider).setActive(
            studentId: student.uid,
            courseId: e.courseId,
            isActive: false,
          );
      if (context.mounted) {
        AppFeedback.showSuccess(
            context, 'Removed from ${e.courseCode ?? 'the course'}.');
      }
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}
