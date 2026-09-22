import 'package:am_in/core/utils/formatters.dart';
import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';

/// Builds attendance CSV text. Kept as a pure function (no I/O) so it is easy
/// to unit-test and reuse for copy-to-clipboard, file export or sharing.
class CsvExporter {
  const CsvExporter._();

  /// A CSV of the attendance [records] for one [session].
  ///
  /// Columns: Course Code, Course Name, Session Date, Student Name,
  /// Admission Number, Status, Marked At, Distance (m).
  static String sessionCsv(
    AttendanceSession session,
    List<AttendanceRecord> records,
  ) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(<String>[
        'Course Code',
        'Course Name',
        'Session Date',
        'Student Name',
        'Admission Number',
        'Status',
        'Marked At',
        'Distance (m)',
      ].map(_escape).join(','));

    for (final AttendanceRecord r in records) {
      buffer.writeln(<String>[
        session.courseCode,
        session.courseName,
        Formatters.dateTime(session.startedAt ?? session.createdAt),
        r.studentName,
        r.admissionNumber ?? '',
        r.status,
        Formatters.dateTime(r.markedAt),
        r.distanceFromLecturer?.round().toString() ?? '',
      ].map(_escape).join(','));
    }

    return buffer.toString();
  }

  /// Escapes a single CSV field per RFC 4180: wrap in quotes if it contains a
  /// comma, quote or newline, and double any embedded quotes.
  static String _escape(String value) {
    final bool needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final String escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
