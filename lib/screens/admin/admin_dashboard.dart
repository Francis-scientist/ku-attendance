import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/models/user_role.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/stat_card.dart';
import 'package:am_in/widgets/status_chip.dart';

/// The administrator's overview: headline counts across the platform plus a
/// live list of every session currently running.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);
    final AsyncValue<List<AppUser>> studentsAsync =
        ref.watch(usersByRoleProvider(UserRole.student));
    final AsyncValue<List<AppUser>> lecturersAsync =
        ref.watch(usersByRoleProvider(UserRole.lecturer));
    final AsyncValue<List<Course>> coursesAsync =
        ref.watch(allCoursesProvider);
    final AsyncValue<List<AttendanceSession>> activeAsync =
        ref.watch(activeSessionsProvider);

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KU Attendance'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(usersByRoleProvider(UserRole.student))
            ..invalidate(usersByRoleProvider(UserRole.lecturer))
            ..invalidate(allCoursesProvider)
            ..invalidate(activeSessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            userAsync.maybeWhen(
              data: (AppUser? user) => Text(
                'Welcome${user != null ? ', ${user.firstName}' : ''}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Text(
              'Administrator overview',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: <Widget>[
                StatCard(
                  icon: Icons.school,
                  value: _count(studentsAsync),
                  label: 'Students',
                  color: theme.colorScheme.primary,
                ),
                StatCard(
                  icon: Icons.co_present,
                  value: _count(lecturersAsync),
                  label: 'Lecturers',
                  color: Colors.teal,
                ),
                StatCard(
                  icon: Icons.menu_book,
                  value: _count(coursesAsync),
                  label: 'Courses',
                  color: Colors.deepPurple,
                ),
                StatCard(
                  icon: Icons.sensors,
                  value: _count(activeAsync),
                  label: 'Live sessions',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Live now',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _LiveSessions(activeAsync: activeAsync),
          ],
        ),
      ),
    );
  }

  /// A stat's display value: the list length, or '—' while loading/errored.
  String _count(AsyncValue<List<Object?>> value) =>
      value.maybeWhen(data: (List<Object?> l) => '${l.length}', orElse: () => '—');
}

class _LiveSessions extends StatelessWidget {
  const _LiveSessions({required this.activeAsync});

  final AsyncValue<List<AttendanceSession>> activeAsync;

  @override
  Widget build(BuildContext context) {
    return activeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingView(),
      ),
      error: (_, _) =>
          const ErrorView(message: 'Could not load live sessions.'),
      data: (List<AttendanceSession> sessions) {
        final List<AttendanceSession> open =
            sessions.where((AttendanceSession s) => s.isOpen).toList();
        if (open.isEmpty) {
          return const EmptyView(
            icon: Icons.nightlight_outlined,
            title: 'Nothing live',
            subtitle: 'Active attendance sessions will appear here.',
          );
        }
        return Column(
          children: open
              .map((AttendanceSession s) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.sensors)),
                      title: Text(s.courseCode),
                      subtitle: Text(s.courseName),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          StatusChip.positive('${s.presentCount} present'),
                          const SizedBox(height: 2),
                          Text(
                            'since ${Formatters.time(s.startedAt ?? s.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
