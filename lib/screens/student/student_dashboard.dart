import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/enrollment.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/routes/app_router.dart';
import 'package:am_in/widgets/countdown_text.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Student home tab: a greeting, quick stats, and — most importantly — the
/// sessions the student can mark right now (active sessions for their enrolled
/// courses), updated live via Firestore streams.
class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('KU Attendance')),
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
    final AsyncValue<List<Enrollment>> enrollmentsAsync =
        ref.watch(studentEnrollmentsProvider(user.uid));
    final AsyncValue<List<AttendanceSession>> activeAsync =
        ref.watch(activeSessionsProvider);
    final AsyncValue<List<AttendanceRecord>> historyAsync =
        ref.watch(studentHistoryProvider(user.uid));

    // Error/loading gates on the two streams that drive the "mark now" list.
    if (enrollmentsAsync.hasError) {
      return const ErrorView(message: 'Could not load your courses.');
    }
    if (activeAsync.hasError) {
      return const ErrorView(message: 'Could not load active sessions.');
    }
    if (enrollmentsAsync.isLoading || activeAsync.isLoading) {
      return const LoadingView();
    }

    final List<Enrollment> enrollments = enrollmentsAsync.value!;
    final Set<String> enrolledCourseIds =
        enrollments.map((Enrollment e) => e.courseId).toSet();

    // Sessions the student may act on: active, not clock-expired, and for a
    // course they're enrolled in.
    final List<AttendanceSession> openSessions = activeAsync.value!
        .where((AttendanceSession s) =>
            s.isOpen && enrolledCourseIds.contains(s.courseId))
        .toList();

    final List<AttendanceRecord> history = historyAsync.value ?? <AttendanceRecord>[];
    final Set<String> markedSessionIds =
        history.map((AttendanceRecord r) => r.sessionId).toSet();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentEnrollmentsProvider(user.uid));
        ref.invalidate(activeSessionsProvider);
        ref.invalidate(studentHistoryProvider(user.uid));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Hello, ${user.firstName} 👋',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            user.identifier,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  icon: Icons.menu_book,
                  value: '${enrollments.length}',
                  label: 'Courses',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.check_circle,
                  value: '${history.length}',
                  label: 'Sessions attended',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Active now',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (openSessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.event_busy_outlined,
                        color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No active sessions right now. When a lecturer starts '
                        'one for your course, it will appear here.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...openSessions.map((AttendanceSession s) => _ActiveSessionCard(
                  session: s,
                  alreadyMarked: markedSessionIds.contains(s.id),
                )),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.session,
    required this.alreadyMarked,
  });

  final AttendanceSession session;
  final bool alreadyMarked;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    session.courseCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (alreadyMarked)
                  StatusChip.positive('Marked', icon: Icons.check)
                else
                  Row(
                    children: <Widget>[
                      Icon(Icons.timer_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      CountdownText(
                        expiresAt: session.expiresAt ?? DateTime.now(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(session.courseName,
                style: theme.textTheme.bodyMedium),
            if (session.lecturerName != null) ...<Widget>[
              const SizedBox(height: 2),
              Text('by ${session.lecturerName}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: alreadyMarked
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Attendance recorded'),
                    )
                  : FilledButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.markAttendance}/${session.id}',
                        extra: session,
                      ),
                      icon: const Icon(Icons.how_to_reg),
                      label: const Text('Mark attendance'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
