import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/account_active_switch.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Admin: browse lecturers, enable/disable accounts, and assign the courses
/// each lecturer teaches.
class ManageLecturers extends ConsumerStatefulWidget {
  const ManageLecturers({super.key});

  @override
  ConsumerState<ManageLecturers> createState() => _ManageLecturersState();
}

class _ManageLecturersState extends ConsumerState<ManageLecturers> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppUser>> lecturersAsync =
        ref.watch(usersByRoleProvider(UserRole.lecturer));

    return Scaffold(
      appBar: AppBar(title: const Text('Lecturers')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              hintText: 'Search name or staff no.',
              leading: const Icon(Icons.search),
              onChanged: (String v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<AppUser>>(
              value: lecturersAsync,
              onRetry: () =>
                  ref.invalidate(usersByRoleProvider(UserRole.lecturer)),
              emptyBuilder: () => const EmptyView(
                icon: Icons.co_present_outlined,
                title: 'No lecturers yet',
                subtitle: 'Lecturers who register will appear here.',
              ),
              dataBuilder: (List<AppUser> lecturers) {
                final List<AppUser> filtered = _filter(lecturers);
                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle: 'Try a different name or staff number.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int i) =>
                      _LecturerTile(lecturer: filtered[i]),
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
          (u.staffNumber ?? '').toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
    }).toList();
  }
}

class _LecturerTile extends StatelessWidget {
  const _LecturerTile({required this.lecturer});

  final AppUser lecturer;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withValues(alpha: 0.15),
          foregroundColor: Colors.teal,
          child: Text(
            lecturer.firstName.isNotEmpty
                ? lecturer.firstName[0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(lecturer.name),
        subtitle: Text(lecturer.staffNumber ?? lecturer.email),
        trailing: lecturer.isActive
            ? StatusChip.positive('Active')
            : StatusChip.negative('Disabled'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _LecturerSheet(lecturer: lecturer),
        ),
      ),
    );
  }
}

/// Detail sheet for one lecturer: toggle their account and assign courses.
class _LecturerSheet extends ConsumerWidget {
  const _LecturerSheet({required this.lecturer});

  final AppUser lecturer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Course>> coursesAsync =
        ref.watch(allCoursesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            Text(lecturer.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(lecturer.email,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (lecturer.staffNumber != null) ...<Widget>[
              const SizedBox(height: 2),
              Text('Staff: ${lecturer.staffNumber}',
                  style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            AccountActiveSwitch(user: lecturer),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Courses taught',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _assign(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            coursesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('Could not load courses.'),
              data: (List<Course> courses) {
                final List<Course> taught = courses
                    .where((Course c) => c.hasLecturer(lecturer.uid))
                    .toList();
                if (taught.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Not assigned to any course yet.'),
                  );
                }
                return Column(
                  children: taught
                      .map((Course c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(c.courseCode),
                            subtitle: Text(c.courseName),
                            trailing: IconButton(
                              tooltip: 'Unassign',
                              icon: const Icon(Icons.remove_circle_outline),
                              color: theme.colorScheme.error,
                              onPressed: () => _unassign(context, ref, c),
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

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final List<Course>? courses = ref.read(allCoursesProvider).valueOrNull;
    if (courses == null || courses.isEmpty) {
      AppFeedback.showInfo(context, 'Create a course first.');
      return;
    }
    final List<Course> available = courses
        .where((Course c) => c.isActive && !c.hasLecturer(lecturer.uid))
        .toList();
    if (available.isEmpty) {
      AppFeedback.showInfo(
          context, 'This lecturer already teaches every active course.');
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
          .read(courseRepositoryProvider)
          .assignLecturer(chosen.id, lecturer.uid);
      if (context.mounted) {
        AppFeedback.showSuccess(
            context, 'Assigned to ${chosen.courseCode}.');
      }
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }

  Future<void> _unassign(
      BuildContext context, WidgetRef ref, Course c) async {
    try {
      await ref
          .read(courseRepositoryProvider)
          .unassignLecturer(c.id, lecturer.uid);
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Unassigned from ${c.courseCode}.');
      }
    } catch (error) {
      if (context.mounted) AppFeedback.showError(context, error);
    }
  }
}
