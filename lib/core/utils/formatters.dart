import 'package:intl/intl.dart';

/// Presentation helpers for dates, times, percentages and the session
/// countdown. Centralised so formatting is consistent across every screen.
class Formatters {
  Formatters._();

  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String time(DateTime? value) =>
      value == null ? '—' : _time.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);

  /// Formats an attendance percentage (0–100) as a whole-number string.
  static String percent(double value) => '${value.clamp(0, 100).round()}%';

  /// Formats a countdown as MM:SS (e.g. 08:42).
  static String countdown(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
