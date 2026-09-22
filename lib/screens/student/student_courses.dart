import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/enrollment.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/state_views.dart';

/// The student's enrolled courses (read-only — enrolment is managed by admins).
/// Each row shows how many sessions the student has attended for that course.
class StudentCourses extends ConsumerWidget {
  const StudentCourses({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My courses')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Could not load your profile.'),
        data: (AppUser? user) {
          if (user == null) {
            return const ErrorView(message: 'No profile found.');
          }
          return _CoursesBody(uid: user.uid);
        },
      ),
    );
  }
}

class _CoursesBody extends ConsumerWidget {
  const _CoursesBody({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Enrollment>> enrollmentsAsync =
        ref.watch(studentEnrollmentsProvider(uid));
    final List<AttendanceRecord> history =
        ref.watch(studentHistoryProvider(uid)).value ?? <AttendanceRecord>[];

    // Attended-session count per course, for the subtitle.
    final Map<String, int> attendedByCourse = <String, int>{};
    for (final AttendanceRecord r in history) {
      attendedByCourse.update(r.courseId, (int v) => v + 1, ifAbsent: () => 1);
    }

    return AsyncValueView<List<Enrollment>>(
      value: enrollmentsAsync,
      onRetry: () => ref.invalidate(studentEnrollmentsProvider(uid)),
      emptyBuilder: () => const EmptyView(
        icon: Icons.menu_book_outlined,
        title: 'No courses yet',
        subtitle:
            'You are not enrolled in any courses. Contact your department if '
            'this looks wrong.',
      ),
      dataBuilder: (List<Enrollment> enrollments) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: enrollments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (BuildContext context, int i) {
          final Enrollment e = enrollments[i];
          final int attended = attendedByCourse[e.courseId] ?? 0;
          final ThemeData theme = Theme.of(context);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  (e.courseCode ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                e.courseCode ?? 'Course',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(e.courseName ?? ''),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('$attended',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      )),
                  Text('attended', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
