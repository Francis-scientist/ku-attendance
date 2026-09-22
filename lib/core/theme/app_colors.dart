import 'package:flutter/material.dart';

/// KU Attendance colour palette.
///
/// A scholarly deep blue (Kenyatta University identity) with a gold accent.
/// Semantic colours (success / warning / error) are shared across light and
/// dark themes; surfaces differ per brightness.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0B3D91); // KU deep blue
  static const Color primaryDark = Color(0xFF072A66);
  static const Color accent = Color(0xFFF2B01E); // gold

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Neutrals — light
  static const Color surfaceLight = Color(0xFFF6F7FB);
  static const Color cardLight = Colors.white;

  // Neutrals — dark
  static const Color surfaceDark = Color(0xFF101216);
  static const Color cardDark = Color(0xFF1B1E24);
}
