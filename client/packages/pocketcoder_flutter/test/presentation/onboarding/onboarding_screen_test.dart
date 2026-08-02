import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockStatusRepository extends Mock implements IStatusRepository {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRepository authRepo;
  late MockStatusRepository statusRepo;
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    authRepo = MockAuthRepository();
    statusRepo = MockStatusRepository();
    when(() => statusRepo.checkPocketBaseHealth())
        .thenAnswer((_) async => true);

    getIt.registerFactory<AuthCubit>(() => AuthCubit(authRepo));
    getIt.registerFactory<IStatusRepository>(() => statusRepo);
    // OnboardingScreen's no-prefill path calls _restoreSavedUrl(), which
    // reads getIt<FlutterSecureStorage>() -- must be registered even
    // though this test never asserts on its value.
    secureStorage = MockFlutterSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    getIt.registerFactory<FlutterSecureStorage>(() => secureStorage);
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestable({OnboardingPrefill? prefill}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PocoCubit>(create: (_) => PocoCubit()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(prefill: prefill),
      ),
    );
  }

  testWidgets('pre-fills url/email/password fields when prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable(
      prefill: const OnboardingPrefill(
        url: 'https://1.2.3.4.sslip.io',
        email: 'admin@pocketcoder.local',
        password: 'correct-horse-battery-staple',
      ),
    ));
    await tester.pump();

    expect(find.text('https://1.2.3.4.sslip.io'), findsOneWidget);
    expect(find.text('admin@pocketcoder.local'), findsOneWidget);
    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('falls back to the default local url when no prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    // findsWidgets, not findsOneWidget: TerminalTextField's hint text is
    // coincidentally the same string as the default value, so it's
    // rendered twice (the field's real EditableText plus its own hint
    // label) purely because hint == value here, not a real duplicate.
    expect(find.text('http://127.0.0.1:8090'), findsWidgets);
  });

  testWidgets('DEPLOY mode shows only email/password, hides the URL field',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    expect(find.text('http://127.0.0.1:8090'), findsNothing);
  });

  testWidgets('DEPLOY mode blocks submission when password is empty',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('deployEmailField')), 'reviewer@example.com');
    await tester.pump();

    await tester.tap(find.text('DEPLOY').last);
    await tester.pump();

    // Still on OnboardingScreen -- no navigation happened.
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets(
      'DEPLOY mode navigates with the entered email/password when both are filled',
      (tester) async {
    // The existing buildTestable() wraps OnboardingScreen in a plain
    // MaterialApp with no GoRouter ancestor -- fine for the two tests
    // above (neither one navigates), but this test needs a real router
    // to observe what OnboardingScreen actually pushes.
    DeployCredentials? capturedExtra;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          name: RouteNames.deploy,
          path: '/deploy',
          builder: (context, state) {
            capturedExtra = state.extra as DeployCredentials?;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PocoCubit>(create: (_) => PocoCubit()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('deployEmailField')), 'reviewer@example.com');
    await tester.enterText(find.byType(TextField).last, 'chosen-password');
    await tester.pump();

    await tester.tap(find.text('DEPLOY').last);
    await tester.pumpAndSettle();

    expect(capturedExtra, isNotNull);
    expect(capturedExtra!.email, 'reviewer@example.com');
    expect(capturedExtra!.password, 'chosen-password');
  });
}
