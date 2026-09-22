import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// The student's full attendance history across all courses, newest first.
class StudentHistory extends ConsumerWidget {
  const StudentHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Could not load your profile.'),
        data: (AppUser? user) {
          if (user == null) {
            return const ErrorView(message: 'No profile found.');
          }
          return _HistoryBody(uid: user.uid);
        },
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AttendanceRecord>> historyAsync =
        ref.watch(studentHistoryProvider(uid));

    return AsyncValueView<List<AttendanceRecord>>(
      value: historyAsync,
      onRetry: () => ref.invalidate(studentHistoryProvider(uid)),
      emptyBuilder: () => const EmptyView(
        icon: Icons.history,
        title: 'No attendance yet',
        subtitle: 'Sessions you mark will appear here.',
      ),
      dataBuilder: (List<AttendanceRecord> records) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (BuildContext context, int i) {
          final AttendanceRecord r = records[i];
          final ThemeData theme = Theme.of(context);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: const Icon(Icons.check),
              ),
              title: Text(
                r.courseCode ?? r.courseId,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                <String?>[r.courseName, Formatters.dateTime(r.markedAt)]
                    .where((String? s) => s != null && s.isNotEmpty)
                    .join('  •  '),
              ),
              trailing: StatusChip.positive('Present'),
            ),
          );
        },
      ),
    );
  }
}
