import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/core/constants/app_constants.dart';
import 'package:am_in/models/app_user.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/auth_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/repositories/attendance_repository.dart';
import 'package:am_in/routes/app_router.dart';
import 'package:am_in/services/location_service.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/primary_button.dart';
import 'package:am_in/widgets/state_views.dart';

/// Where a lecturer configures and starts an attendance session: pick the
/// geofence radius and duration, then start. Starting captures the lecturer's
/// current location (the geofence centre) and generates the OTP.
class StartAttendanceScreen extends ConsumerStatefulWidget {
  const StartAttendanceScreen({
    super.key,
    required this.courseId,
    this.course,
  });

  final String courseId;
  final Course? course;

  @override
  ConsumerState<StartAttendanceScreen> createState() =>
      _StartAttendanceScreenState();
}

class _StartAttendanceScreenState
    extends ConsumerState<StartAttendanceScreen> {
  double _radius = AppConstants.defaultRadiusMeters;
  int _duration = AppConstants.defaultSessionMinutes;
  bool _starting = false;
  String? _statusMessage;

  Future<void> _start(Course course, AppUser lecturer) async {
    setState(() {
      _starting = true;
      _statusMessage = 'Getting your location…';
    });
    try {
      final LocationReading reading =
          await ref.read(locationServiceProvider).getCurrentReading();

      if (!mounted) return;
      setState(() => _statusMessage = 'Starting session…');

      final StartedSession started =
          await ref.read(attendanceRepositoryProvider).startSession(
                course: course,
                lecturer: lecturer,
                latitude: reading.latitude,
                longitude: reading.longitude,
                radius: _radius,
                durationMinutes: _duration,
              );

      if (!mounted) return;
      // Replace this screen so "back" from the live view returns to the
      // dashboard, not the setup form.
      context.pushReplacement(
        '${AppRoutes.liveAttendance}/${started.sessionId}',
      );
    } catch (error) {
      if (!mounted) return;
      AppFeedback.showError(context, error);
      setState(() {
        _starting = false;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? lecturer = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Start attendance')),
      body: widget.course != null
          ? _buildBody(widget.course!, lecturer)
          : ref.watch(courseByIdProvider(widget.courseId)).when(
                loading: () => const LoadingView(),
                error: (_, _) =>
                    const ErrorView(message: 'Could not load the course.'),
                data: (Course? c) => c == null
                    ? const ErrorView(message: 'Course not found.')
                    : _buildBody(c, lecturer),
              ),
    );
  }

  Widget _buildBody(Course course, AppUser? lecturer) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.menu_book),
            ),
            title: Text(course.courseCode,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(course.courseName),
          ),
        ),
        const SizedBox(height: 24),
        Text('Geofence radius',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Students must be within this distance of you to mark attendance.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final int r in AppConstants.radiusOptions)
              ChoiceChip(
                label: Text('$r m'),
                selected: _radius == r.toDouble(),
                onSelected: _starting
                    ? null
                    : (_) => setState(() => _radius = r.toDouble()),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Session duration',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'The code stops working automatically after this time.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final int m in AppConstants.sessionDurationOptions)
              ChoiceChip(
                label: Text('$m min'),
                selected: _duration == m,
                onSelected:
                    _starting ? null : (_) => setState(() => _duration = m),
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (_statusMessage != null) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(_statusMessage!),
            ],
          ),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: 'Start session',
          icon: Icons.play_arrow,
          isLoading: _starting,
          onPressed: lecturer == null ? null : () => _start(course, lecturer),
        ),
        const SizedBox(height: 12),
        Text(
          'A 4-digit code will be generated. Read it out to your students — '
          'it is never sent to them automatically.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
