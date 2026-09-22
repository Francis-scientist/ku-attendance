import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/countdown_text.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// The lecturer's live session view: shows the OTP to read out, a countdown,
/// and the roster of students filling in as they mark — all in real time via
/// Firestore streams. The lecturer can close the session at any point.
class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<LiveAttendanceScreen> createState() =>
      _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  bool _closing = false;

  Future<void> _confirmClose() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Close session?'),
        content: const Text(
          'No more students will be able to mark attendance once this session '
          'is closed. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close session'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;

    setState(() => _closing = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .closeSession(widget.sessionId);
      if (mounted) AppFeedback.showSuccess(context, 'Session closed.');
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AttendanceSession?> sessionAsync =
        ref.watch(sessionProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionAsync.value?.courseCode ?? 'Live session'),
      ),
      body: sessionAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Could not load the session.'),
        data: (AttendanceSession? session) {
          if (session == null) {
            return const ErrorView(message: 'Session not found.');
          }
          return _buildBody(session);
        },
      ),
    );
  }

  Widget _buildBody(AttendanceSession session) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<AttendanceRecord>> recordsAsync =
        ref.watch(sessionRecordsProvider(widget.sessionId));
    final bool open = session.isOpen;

    return Column(
      children: <Widget>[
        _HeaderCard(
          session: session,
          open: open,
          closing: _closing,
          onClose: _confirmClose,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Text('Marked present',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              recordsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (List<AttendanceRecord> r) =>
                    StatusChip.neutral('${r.length}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: recordsAsync.when(
            loading: () => const LoadingView(),
            error: (_, _) =>
                const ErrorView(message: 'Could not load the attendance list.'),
            data: (List<AttendanceRecord> records) {
              if (records.isEmpty) {
                return const EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'No one yet',
                  subtitle:
                      'Students who mark attendance will appear here instantly.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: records.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final AttendanceRecord r = records[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
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
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.session,
    required this.open,
    required this.closing,
    required this.onClose,
  });

  final AttendanceSession session;
  final bool open;
  final bool closing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<String?> otpAsync =
        ref.watch(sessionOtpProvider(session.id));

    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(session.courseName,
                    style: const TextStyle(color: Colors.white70)),
                if (open)
                  StatusChip.positive('LIVE', icon: Icons.circle)
                else
                  StatusChip.neutral('Closed'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ATTENDANCE CODE',
                style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 12)),
            const SizedBox(height: 8),
            otpAsync.when(
              loading: () => const Text('••••',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold)),
              error: (_, _) => const Text('----',
                  style: TextStyle(color: Colors.white70, fontSize: 44)),
              data: (String? otp) {
                final String code = otp ?? '----';
                return GestureDetector(
                  onTap: open
                      ? () {
                          Clipboard.setData(ClipboardData(text: code));
                          AppFeedback.showInfo(context, 'Code copied.');
                        }
                      : null,
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _HeaderStat(
                  icon: Icons.timer_outlined,
                  child: open
                      ? CountdownText(
                          expiresAt: session.expiresAt ?? DateTime.now(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        )
                      : const Text('Ended',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                _HeaderStat(
                  icon: Icons.people_outline,
                  child: Text('${session.presentCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
                _HeaderStat(
                  icon: Icons.my_location,
                  child: Text('${session.radius.round()} m',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
              ],
            ),
            if (open) ...<Widget>[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: closing ? null : onClose,
                  icon: closing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.stop_circle_outlined),
                  label: const Text('Close session'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
