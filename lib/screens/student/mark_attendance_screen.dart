import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/core/utils/validators.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/countdown_text.dart';
import 'package:am_in/widgets/otp_field.dart';
import 'package:am_in/widgets/primary_button.dart';
import 'package:am_in/widgets/state_views.dart';

/// Where a student enters the lecturer's OTP and marks attendance.
///
/// The screen never decides the outcome itself: it obtains a location fix and
/// calls the `markAttendance` Cloud Function, which is the sole authority on
/// OTP, geofence, enrolment, timing and duplicates. Success is confirmed by the
/// student's own record appearing in Firestore (streamed live).
class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({
    super.key,
    required this.sessionId,
    this.session,
  });

  final String sessionId;

  /// Optional pre-fetched session passed via router `extra` to avoid a flash of
  /// loading; the live [sessionProvider] remains the source of truth.
  final AttendanceSession? session;

  @override
  ConsumerState<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otp = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve the live session and signed-in student (rules + the write need
    // both). Fall back to the session passed via router `extra`.
    final AttendanceSession? session =
        ref.read(sessionProvider(widget.sessionId)).value ?? widget.session;
    final AppUser? user = ref.read(currentUserProvider).value;
    if (session == null || user == null) {
      AppFeedback.showError(
          context, 'This session is no longer available. Please go back.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref.read(attendanceRepositoryProvider).markAttendance(
            session: session,
            student: user,
            otp: _otp.text.trim(),
          );
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'Attendance marked. You are present ✓');
      // The ownRecord stream will flip the UI to the confirmed state.
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AttendanceSession?> sessionAsync =
        ref.watch(sessionProvider(widget.sessionId));
    final AppUser? user = ref.watch(currentUserProvider).value;

    // Prefer the live session, fall back to the one passed via router extra.
    final AttendanceSession? session = sessionAsync.value ?? widget.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Mark attendance')),
      body: sessionAsync.isLoading && session == null
          ? const LoadingView()
          : session == null
              ? const ErrorView(
                  message:
                      'This session is no longer available. It may have been '
                      'closed.',
                )
              : _buildContent(context, session, user),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AttendanceSession session,
    AppUser? user,
  ) {
    // If the student already has a record for this session, show confirmation.
    if (user != null) {
      final AsyncValue<AttendanceRecord?> ownRecord = ref.watch(
        ownRecordProvider(
          (sessionId: widget.sessionId, studentId: user.uid),
        ),
      );
      final AttendanceRecord? record = ownRecord.value;
      if (record != null) {
        return _ConfirmedView(session: session, record: record);
      }
    }

    final ThemeData theme = Theme.of(context);
    final bool open = session.isOpen;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(session.courseCode,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(session.courseName, style: theme.textTheme.bodyMedium),
                if (session.lecturerName != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text('by ${session.lecturerName}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.timer_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        if (open)
                          CountdownText(
                            expiresAt: session.expiresAt ?? DateTime.now(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            onExpired: () {
                              if (mounted) setState(() {});
                            },
                          )
                        else
                          Text('Closed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              )),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Icon(Icons.my_location,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text('within ${session.radius.round()} m',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!open)
          const _ClosedNotice()
        else ...<Widget>[
          Text(
            'Enter the code your lecturer read out. You must be inside the '
            'classroom — your location is checked.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: OtpField(
              controller: _otp,
              autofocus: true,
              enabled: !_submitting,
              validator: Validators.otp,
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Mark me present',
            icon: Icons.how_to_reg,
            isLoading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          Text(
            'We only use your location at this moment to confirm you are in '
            'class. It is not tracked afterwards.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.session, required this.record});

  final AttendanceSession session;
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle,
                size: 88, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text("You're marked present",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${session.courseCode} — ${session.courseName}',
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text('at ${Formatters.time(record.markedAt)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (record.distanceFromLecturer != null) ...<Widget>[
              const SizedBox(height: 4),
              Text('${record.distanceFromLecturer!.round()} m from lecturer',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.lock_clock, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This session is closed. You can no longer mark attendance.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
