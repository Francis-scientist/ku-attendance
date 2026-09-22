import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/routes/app_router.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// A lecturer's recent attendance sessions (most recent first). Tapping a row
/// opens the live/detail view — which also works for closed sessions.
class LecturerHistory extends ConsumerWidget {
  const LecturerHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My sessions')),
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
    final AsyncValue<List<AttendanceSession>> sessionsAsync =
        ref.watch(lecturerSessionsProvider(uid));

    return AsyncValueView<List<AttendanceSession>>(
      value: sessionsAsync,
      onRetry: () => ref.invalidate(lecturerSessionsProvider(uid)),
      emptyBuilder: () => const EmptyView(
        icon: Icons.history,
        title: 'No sessions yet',
        subtitle: 'Sessions you start will be listed here.',
      ),
      dataBuilder: (List<AttendanceSession> sessions) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (BuildContext context, int i) {
          final AttendanceSession s = sessions[i];
          final ThemeData theme = Theme.of(context);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () =>
                  context.push('${AppRoutes.liveAttendance}/${s.id}'),
              title: Text(s.courseCode,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(Formatters.dateTime(s.createdAt ?? s.startedAt)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('${s.presentCount}',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      Text('present', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(width: 8),
                  s.isOpen
                      ? StatusChip.positive('Live')
                      : StatusChip.neutral('Ended'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
