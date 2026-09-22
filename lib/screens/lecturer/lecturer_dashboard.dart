import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/routes/app_router.dart';
import 'package:am_in/widgets/countdown_text.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Lecturer home tab: their assigned courses (each can start an attendance
/// session) and any sessions they currently have running.
class LecturerDashboard extends ConsumerWidget {
  const LecturerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teach')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Could not load your profile.'),
        data: (AppUser? user) {
          if (user == null) {
            return const ErrorView(message: 'No profile found.');
          }
          return _DashboardBody(user: user);
        },
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Course>> coursesAsync =
        ref.watch(lecturerCoursesProvider(user.uid));

    // Reuse the active-sessions stream (single-field index) and filter to this
    // lecturer's open sessions client-side — no composite index needed here.
    final List<AttendanceSession> myActive =
        (ref.watch(activeSessionsProvider).value ?? <AttendanceSession>[])
            .where((AttendanceSession s) => s.lecturerId == user.uid && s.isOpen)
            .toList();
    final Map<String, AttendanceSession> activeByCourse =
        <String, AttendanceSession>{
      for (final AttendanceSession s in myActive) s.courseId: s,
    };

    return coursesAsync.when(
      loading: () => const LoadingView(),
      error: (_, _) => ErrorView(
        message: 'Could not load your courses.',
        onRetry: () => ref.invalidate(lecturerCoursesProvider(user.uid)),
      ),
      data: (List<Course> courses) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(lecturerCoursesProvider(user.uid));
            ref.invalidate(activeSessionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text('Hello, ${user.firstName}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (myActive.isNotEmpty) ...<Widget>[
                Text('Live now',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...myActive.map((AttendanceSession s) =>
                    _LiveSessionCard(session: s)),
                const SizedBox(height: 24),
              ],
              Text('Your courses',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (courses.isEmpty)
                const EmptyView(
                  icon: Icons.co_present_outlined,
                  title: 'No courses assigned',
                  subtitle:
                      'You have no courses yet. An administrator assigns '
                      'courses to lecturers.',
                )
              else
                ...courses.map((Course c) => _CourseTile(
                      course: c,
                      activeSession: activeByCourse[c.id],
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course, this.activeSession});

  final Course course;
  final AttendanceSession? activeSession;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLive = activeSession != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(
            course.courseCode.isNotEmpty
                ? course.courseCode.characters.first.toUpperCase()
                : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(course.courseCode,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(course.courseName,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: isLive
            ? FilledButton.tonal(
                onPressed: () => context.push(
                  '${AppRoutes.liveAttendance}/${activeSession!.id}',
                ),
                child: const Text('Live'),
              )
            : FilledButton(
                onPressed: () => context.push(
                  '${AppRoutes.startAttendance}/${course.id}',
                  extra: course,
                ),
                child: const Text('Start'),
              ),
      ),
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  const _LiveSessionCard({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('${AppRoutes.liveAttendance}/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        StatusChip.positive('LIVE', icon: Icons.circle),
                        const SizedBox(width: 8),
                        Text('${session.presentCount} present',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(session.courseCode,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(session.courseName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  CountdownText(
                    expiresAt: session.expiresAt ?? DateTime.now(),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
