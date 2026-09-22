import 'package:flutter_test/flutter_test.dart';

import 'package:am_in/models/attendance_record.dart';
import 'package:am_in/models/attendance_session.dart';
import 'package:am_in/core/utils/csv_exporter.dart';

/// The CSV export is a pure function, so we can assert its exact output —
/// header row, field order, and RFC 4180 quoting of awkward values.
void main() {
  final AttendanceSession session = AttendanceSession(
    id: 's1',
    courseId: 'c1',
    courseCode: 'SCO 209',
    courseName: 'Computer Organization',
    lecturerId: 'lec1',
    latitude: -1.2921,
    longitude: 36.8219,
    radius: 50,
    durationMinutes: 15,
    startedAt: DateTime(2026, 3, 14, 9, 30),
    createdAt: DateTime(2026, 3, 14, 9, 30),
  );

  test('header lists the eight columns in order', () {
    final String csv = CsvExporter.sessionCsv(session, <AttendanceRecord>[]);
    final String header = csv.trim();
    expect(
      header,
      'Course Code,Course Name,Session Date,Student Name,'
      'Admission Number,Status,Marked At,Distance (m)',
    );
  });

  test('writes one data row per record with distance rounded', () {
    final List<AttendanceRecord> records = <AttendanceRecord>[
      AttendanceRecord(
        studentId: 'u1',
        studentName: 'Jane Doe',
        admissionNumber: 'CS001/2024',
        courseId: 'c1',
        sessionId: 's1',
        markedAt: DateTime(2026, 3, 14, 9, 32),
        distanceFromLecturer: 12.6,
        status: 'present',
      ),
    ];
    final List<String> lines =
        CsvExporter.sessionCsv(session, records).trim().split('\n');
    expect(lines.length, 2); // header + 1 row
    expect(lines[1], contains('Jane Doe'));
    expect(lines[1], contains('CS001/2024'));
    expect(lines[1], contains('present'));
    expect(lines[1], endsWith('13')); // 12.6 rounds to 13
  });

  test('quotes fields containing commas and escapes quotes', () {
    final List<AttendanceRecord> records = <AttendanceRecord>[
      AttendanceRecord(
        studentId: 'u2',
        studentName: 'Doe, "JJ" Junior',
        admissionNumber: null,
        courseId: 'c1',
        sessionId: 's1',
        markedAt: DateTime(2026, 3, 14, 9, 33),
        status: 'present',
      ),
    ];
    final String row =
        CsvExporter.sessionCsv(session, records).trim().split('\n')[1];
    // Name is wrapped in quotes, and embedded quotes are doubled.
    expect(row, contains('"Doe, ""JJ"" Junior"'));
  });

  test('missing admission number renders as an empty field', () {
    final List<AttendanceRecord> records = <AttendanceRecord>[
      AttendanceRecord(
        studentId: 'u3',
        studentName: 'No Adm',
        admissionNumber: null,
        courseId: 'c1',
        sessionId: 's1',
        markedAt: DateTime(2026, 3, 14, 9, 34),
        distanceFromLecturer: null,
        status: 'present',
      ),
    ];
    final String row =
        CsvExporter.sessionCsv(session, records).trim().split('\n')[1];
    // ...,No Adm,,present,... — empty admission field between name and status.
    expect(row, contains(',No Adm,,present,'));
  });
}
