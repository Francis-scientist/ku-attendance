import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:am_in/widgets/primary_button.dart';

/// Widget test for [PrimaryButton] — it must disable itself and hide its label
/// while loading so an action can't be double-submitted.
void main() {
  testWidgets('PrimaryButton shows label and fires onPressed when idle',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Sign in',
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Sign in'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('PrimaryButton is disabled and spins while loading',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Sign in',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    // Label is replaced by a spinner…
    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // …and taps do nothing.
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(taps, 0);
  });
}
