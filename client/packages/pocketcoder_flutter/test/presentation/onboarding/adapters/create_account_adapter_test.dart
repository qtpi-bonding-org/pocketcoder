import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/server_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/create_account_screen.dart';

void main() {
  late List<ServerCredentials?> forwarded;

  Future<void> fill(WidgetTester tester,
      {required String email, required String password}) async {
    forwarded = [];
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingDeploy,
      routes: [
        GoRoute(
          path: AppRoutes.onboardingDeploy,
          builder: (_, __) => const CreateAccountScreen(),
        ),
        GoRoute(
          name: RouteNames.deploy,
          path: AppRoutes.deploy,
          builder: (_, state) {
            forwarded.add(state.extra as ServerCredentials?);
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.pump();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
  }

  testWidgets('an email with surrounding space is an error, not trimmed',
      (tester) async {
    await fill(tester, email: 'admin@example.com ', password: 'password');

    expect(find.text('Remove the space before or after the email'),
        findsOneWidget);
    await next(tester);
    expect(forwarded, isEmpty);
  });

  testWidgets('a password with surrounding space is an error', (tester) async {
    await fill(tester, email: 'admin@example.com', password: ' password');

    expect(find.text('Remove the space before or after the password'),
        findsOneWidget);
    await next(tester);
    expect(forwarded, isEmpty);
  });

  testWidgets('a password over 71 characters is an error', (tester) async {
    await fill(tester, email: 'admin@example.com', password: 'a' * 72);

    expect(find.text('Must be at most 71 characters'), findsOneWidget);
    await next(tester);
    expect(forwarded, isEmpty);
  });

  testWidgets('length is counted in characters, not UTF-16 units',
      (tester) async {
    await fill(tester, email: 'admin@example.com', password: '😀' * 71);

    expect(find.text('Must be at most 71 characters'), findsNothing);
    await next(tester);
    expect(forwarded.single?.password, '😀' * 71);
  });

  testWidgets('mixed-case email and inner spaces are forwarded verbatim',
      (tester) async {
    await fill(tester, email: 'Admin@Example.com', password: 'pass word');
    await next(tester);

    expect(forwarded.single?.email, 'Admin@Example.com');
    expect(forwarded.single?.password, 'pass word');
  });

  testWidgets('the password field can be revealed', (tester) async {
    await fill(tester, email: 'admin@example.com', password: 'password');

    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue);
    await tester.tap(find.text('show'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
  });
}
