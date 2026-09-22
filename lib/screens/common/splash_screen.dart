import 'package:flutter/material.dart';

import 'package:am_in/core/theme/app_colors.dart';

/// Shown while the router resolves auth + profile state on startup. Kept
/// deliberately minimal — it's on screen for a fraction of a second.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.how_to_reg, size: 72, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'KU Attendance',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kenyatta University',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
