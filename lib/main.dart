import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/app.dart';
import 'firebase_options.dart';

/// Entry point. Initialises Firebase for the current platform, then runs the
/// app inside a Riverpod [ProviderScope] so every provider is available.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: KuAttendanceApp()));
}
