import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:am_in/core/theme/app_theme.dart';
import 'package:am_in/routes/app_router.dart';

/// The root widget. Wires the [GoRouter] (which owns auth/role redirects) and
/// the light/dark themes into a [MaterialApp.router].
class KuAttendanceApp extends ConsumerWidget {
  const KuAttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'KU Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
