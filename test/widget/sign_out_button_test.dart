import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/repositories/auth_repository.dart';
import 'package:am_in/widgets/sign_out_button.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// [SignOutButton] is the single sign-out affordance reused by the admin,
/// lecturer and student interfaces, so its confirm-then-signOut contract is
/// worth pinning down: it must call Firebase Auth's signOut only after the user
/// confirms, and do nothing on cancel.
void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Widget harness() => ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(
          home: Scaffold(
            appBar: null,
            body: Center(child: SignOutButton()),
          ),
        ),
      );

  testWidgets('confirming the dialog signs the user out', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    // The confirmation dialog is shown.
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

    // Confirm via the dialog's FilledButton (not the icon's tooltip).
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    verify(() => auth.signOut()).called(1);
  });

  testWidgets('cancelling the dialog does NOT sign out', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => auth.signOut());
  });
}
