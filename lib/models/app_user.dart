import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// A KU Attendance user profile, stored at `users/{uid}`.
///
/// Passwords are NEVER stored here — Firebase Authentication owns credentials.
/// Students are identified by [admissionNumber], lecturers by [staffNumber];
/// only the field relevant to the role is required.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? admissionNumber; // students
  final String? staffNumber; // lecturers
  final String? department;
  final String? faculty;
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.admissionNumber,
    this.staffNumber,
    this.department,
    this.faculty,
    this.phone,
    this.photoUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isStudent => role == UserRole.student;
  bool get isLecturer => role == UserRole.lecturer;
  bool get isAdmin => role == UserRole.admin;

  /// Best identifier for display, appropriate to the role.
  String get identifier => admissionNumber ?? staffNumber ?? email;

  /// First name, for friendly greetings ("Welcome, Jane").
  String get firstName => name.trim().split(' ').first;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: UserRole.fromString(map['role'] as String?),
      admissionNumber: map['admissionNumber'] as String?,
      staffNumber: map['staffNumber'] as String?,
      department: map['department'] as String?,
      faculty: map['faculty'] as String?,
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isActive: (map['isActive'] ?? true) as bool,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  /// Writable fields only. Server timestamps (`createdAt`/`updatedAt`) are added
  /// by the repository so the client clock is never trusted for them.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'email': email,
        'role': role.name,
        if (admissionNumber != null) 'admissionNumber': admissionNumber,
        if (staffNumber != null) 'staffNumber': staffNumber,
        if (department != null) 'department': department,
        if (faculty != null) 'faculty': faculty,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'isActive': isActive,
      };

  AppUser copyWith({
    String? name,
    String? admissionNumber,
    String? staffNumber,
    String? department,
    String? faculty,
    String? phone,
    String? photoUrl,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      staffNumber: staffNumber ?? this.staffNumber,
      department: department ?? this.department,
      faculty: faculty ?? this.faculty,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
