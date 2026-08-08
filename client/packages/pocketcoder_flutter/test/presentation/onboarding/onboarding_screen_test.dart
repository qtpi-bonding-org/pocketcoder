import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_deploy_credentials_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_login_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockFlutterSecureStorage secureStorage;
  late MockAuthRepository authRepository;

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
    authRepository = MockAuthRepository();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    GetIt.I.registerFactory<FlutterSecureStorage>(() => secureStorage);
    GetIt.I.registerFactory<AuthCubit>(() => AuthCubit(authRepository));
  });

  tearDown(() => GetIt.I.reset());

  Widget buildTestable(Widget child) {
    return MultiBlocProvider(
      providers: [BlocProvider<PocoCubit>(create: (_) => PocoCubit())],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('server choice has separate LOGIN and DEPLOY actions',
      (tester) async {
    await tester.pumpWidget(buildTestable(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('DEPLOY'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('prefilled login page shows server credentials', (tester) async {
    await tester.pumpWidget(buildTestable(
      const OnboardingScreen(
        prefill: OnboardingPrefill(
          url: 'https://1.2.3.4.sslip.io',
          email: 'admin@pocketcoder.local',
          password: 'correct-horse-battery-staple',
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(OnboardingLoginScreen), findsOneWidget);
    expect(find.text('https://1.2.3.4.sslip.io'), findsOneWidget);
    expect(find.text('admin@pocketcoder.local'), findsOneWidget);
    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('deploy credentials forwards an immutable credential object',
      (tester) async {
    DeployCredentials? captured;
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingDeploy,
      routes: [
        GoRoute(
          path: AppRoutes.onboardingDeploy,
          builder: (_, __) => const OnboardingDeployCredentialsScreen(),
        ),
        GoRoute(
          name: RouteNames.deploy,
          path: AppRoutes.deploy,
          builder: (_, state) {
            captured = state.extra as DeployCredentials?;
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

    await tester.enterText(find.byType(TextField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextField).last, 'chosen-password');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.email, 'admin@example.com');
    expect(captured!.password, 'chosen-password');
  });

  testWidgets(
      'BACK does not throw when login screen is the router root '
      '(reachable server, not authenticated boots straight here)',
      (tester) async {
    // Boot reaches this screen via context.goNamed (a stack replace), so
    // there is no previous route to pop back to.
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingLogin,
      routes: [
        GoRoute(
          name: RouteNames.onboardingLogin,
          path: AppRoutes.onboardingLogin,
          builder: (_, __) => const OnboardingLoginScreen(),
        ),
        GoRoute(
          name: RouteNames.onboarding,
          path: AppRoutes.onboarding,
          builder: (_, __) => const Scaffold(body: Text('SERVER CHOICE')),
        ),
      ],
    );

    await tester.pumpWidget(MultiBlocProvider(
      providers: [BlocProvider<PocoCubit>(create: (_) => PocoCubit())],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
