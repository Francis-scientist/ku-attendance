import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/utils/csv_exporter.dart';
import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/primary_button.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Admin reports: choose a course, see its attendance sessions, and export any
/// session's roster as CSV (copied to the clipboard so it can be pasted into a
/// spreadsheet or email).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Course? _course;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Course>> coursesAsync =
        ref.watch(allCoursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: coursesAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Could not load courses.'),
        data: (List<Course> courses) {
          if (courses.isEmpty) {
            return const EmptyView(
              icon: Icons.assessment_outlined,
              title: 'Nothing to report yet',
              subtitle: 'Create courses and run sessions first.',
            );
          }
          // Keep the selected course in sync with the latest data.
          final Course? selected = _course == null
              ? null
              : courses.where((Course c) => c.id == _course!.id).firstOrNull;

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: courses
                      .map((Course c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.courseCode} — ${c.courseName}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (String? id) => setState(() => _course =
                      courses.where((Course c) => c.id == id).firstOrNull),
                ),
              ),
              Expanded(
                child: selected == null
                    ? const EmptyView(
                        icon: Icons.touch_app_outlined,
                        title: 'Choose a course',
                        subtitle:
                            'Pick a course above to see its sessions and export attendance.',
                      )
                    : _SessionList(course: selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AttendanceSession>> sessionsAsync =
        ref.watch(courseSessionsProvider(course.id));

    return AsyncValueView<List<AttendanceSession>>(
      value: sessionsAsync,
      onRetry: () => ref.invalidate(courseSessionsProvider(course.id)),
      emptyBuilder: () => const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'No sessions',
        subtitle: 'This course has no attendance sessions yet.',
      ),
      dataBuilder: (List<AttendanceSession> sessions) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (BuildContext context, int i) {
          final AttendanceSession s = sessions[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.event_available)),
              title: Text(Formatters.dateTime(s.startedAt ?? s.createdAt)),
              subtitle: Text('${s.presentCount} present'),
              trailing: s.isOpen
                  ? StatusChip.positive('Live')
                  : StatusChip.neutral('Ended'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _SessionReport(session: s),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single session's roster with a CSV export action.
class _SessionReport extends ConsumerWidget {
  const _SessionReport({required this.session});

  final AttendanceSession session;

  Future<void> _copyCsv(
      BuildContext context, List<AttendanceRecord> records) async {
    final String csv = CsvExporter.sessionCsv(session, records);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      AppFeedback.showSuccess(
        context,
        'CSV for ${records.length} record${records.length == 1 ? '' : 's'} '
        'copied to clipboard.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<AttendanceRecord>> recordsAsync =
        ref.watch(sessionRecordsProvider(session.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${session.courseCode} — attendance',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(Formatters.dateTime(session.startedAt ?? session.createdAt),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 12),
                  recordsAsync.maybeWhen(
                    data: (List<AttendanceRecord> records) => PrimaryButton(
                      label: records.isEmpty
                          ? 'No records to export'
                          : 'Copy CSV (${records.length})',
                      icon: Icons.copy_all_outlined,
                      onPressed: records.isEmpty
                          ? null
                          : () => _copyCsv(context, records),
                    ),
                    orElse: () => const PrimaryButton(
                      label: 'Copy CSV',
                      icon: Icons.copy_all_outlined,
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncValueView<List<AttendanceRecord>>(
                value: recordsAsync,
                onRetry: () =>
                    ref.invalidate(sessionRecordsProvider(session.id)),
                emptyBuilder: () => const EmptyView(
                  icon: Icons.person_off_outlined,
                  title: 'No attendance',
                  subtitle: 'No students marked attendance in this session.',
                ),
                dataBuilder: (List<AttendanceRecord> records) =>
                    ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final AttendanceRecord r = records[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor:
                            theme.colorScheme.onSecondaryContainer,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(r.studentName.isEmpty
                          ? (r.admissionNumber ?? 'Student')
                          : r.studentName),
                      subtitle: Text(
                        <String?>[
                          r.admissionNumber,
                          if (r.distanceFromLecturer != null)
                            '${r.distanceFromLecturer!.round()} m away',
                        ].where((String? s) => s != null).join('  •  '),
                      ),
                      trailing: Text(Formatters.time(r.markedAt)),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
