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
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/server_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/create_account_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/self_host_login_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/get_started_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/self_host_setup_view.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/welcome_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class _NoopServerReadinessCheck implements IServerReadinessCheck {
  const _NoopServerReadinessCheck();
  @override
  ServerReadinessSnapshot get current =>
      const ServerReadinessSnapshot(status: ServerReadinessStatus.notProvisioned);
  @override
  Stream<ServerReadinessSnapshot> get readinessChanges => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> retry() async {}
}

void main() {
  late MockFlutterSecureStorage secureStorage;
  late MockAuthRepository authRepository;

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
    authRepository = MockAuthRepository();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    GetIt.I.registerFactory<FlutterSecureStorage>(() => secureStorage);
    GetIt.I.registerFactory<AuthCubit>(() => AuthCubit(
          authRepository,
          CaddyCaPinStore(secureStorage),
          const NoopFactoryResetHook(),
          const NoopProDataDeletionHook(),
          FossBillingService(),
          const _NoopServerReadinessCheck(),
        ));
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

  testWidgets('initiative choice asks the question without defining a server',
      (tester) async {
    await tester.pumpWidget(buildTestable(const GetStartedScreen()));
    await tester.pump();

    final question = tester.widget<PocoBubble>(find.byType(PocoBubble));
    expect(
      question.message,
      'Are you already part of the PocketCoder Initiative?',
    );
    expect(find.textContaining('I HAVE A SERVER — LOG IN'), findsOneWidget);
    expect(find.textContaining('I’M NEW — JOIN'), findsOneWidget);
    expect(find.byType(TerminalPromptSuggestion), findsNWidgets(2));
    expect(find.textContaining('computer that stays online'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('welcome defines a server and promises guided setup',
      (tester) async {
    await tester.pumpWidget(buildTestable(WelcomeView(
      showGuidedSetup: true,
      onGuidedSetup: () {},
      onSelfHost: () {},
    )));
    await tester.pump();

    expect(find.text('WELCOME'), findsOneWidget);
    final welcome = tester.widget<PocoBubble>(find.byType(PocoBubble));
    expect(welcome.message, contains('a server—a computer that stays online'));
    expect(welcome.message, contains('accessible and ready'));
    expect(find.textContaining('HELP ME WITH SETUP'), findsOneWidget);
    expect(find.textContaining('I’LL SET IT UP'), findsOneWidget);
    expect(find.byType(TerminalPromptSuggestion), findsNWidgets(2));
  });

  testWidgets('self-host information explains prerequisites', (tester) async {
    await tester.pumpWidget(buildTestable(SelfHostSetupView(
      onOpenGuide: () {},
      onConnect: () {},
    )));
    await tester.pump();

    expect(find.text('SELF-HOST SETUP'), findsOneWidget);
    expect(find.text('A LINUX SERVER OR VPS YOU CONTROL'), findsOneWidget);
    expect(find.text('DOCKER COMPOSE V2'), findsOneWidget);
    expect(find.text('GUIDE'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
  });

  testWidgets('login adapter renders the challenge and form without a server',
      (tester) async {
    await tester.pumpWidget(buildTestable(const SelfHostLoginScreen()));
    await tester.pump();

    expect(find.byType(PocoBubble), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('CONNECT'), findsOneWidget);
  });

  testWidgets('prefilled login page shows server credentials', (tester) async {
    await tester.pumpWidget(buildTestable(
      const GetStartedScreen(
        prefill: OnboardingPrefill(
          url: 'https://1.2.3.4.sslip.io',
          email: 'admin@pocketcoder.local',
          password: 'correct-horse-battery-staple',
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(SelfHostLoginScreen), findsOneWidget);
    expect(find.text('https://1.2.3.4.sslip.io'), findsOneWidget);
    expect(find.text('admin@pocketcoder.local'), findsOneWidget);
    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('deploy credentials forwards an immutable credential object',
      (tester) async {
    ServerCredentials? captured;
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
            captured = state.extra as ServerCredentials?;
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
    await tester.pump();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.email, 'admin@example.com');
    expect(captured!.password, 'chosen-password');
  });

  testWidgets(
      'deploy credentials rejects a password under 8 characters -- '
      "PocketBase's own migration hard-fails on this server-side, minutes "
      'into a live deploy, if the client lets it through', (tester) async {
    ServerCredentials? captured;
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
            captured = state.extra as ServerCredentials?;
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
    await tester.enterText(find.byType(TextField).last, 'short7c');
    await tester.pump();

    expect(find.text('Must be at least 8 characters'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(captured, isNull,
        reason: 'a too-short password must never reach the deploy route');
  });

  testWidgets('deploy credentials continue to the selected provider',
      (tester) async {
    ServerCredentials? captured;
    const provider = ProviderOption(
      id: 'linode',
      name: 'Linode',
      description: 'Managed deployment',
      routePath: '/auth',
    );
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingDeploy,
      routes: [
        GoRoute(
          path: AppRoutes.onboardingDeploy,
          builder: (_, __) => const CreateAccountScreen(
            provider: provider,
          ),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, state) {
            captured = state.extra as ServerCredentials?;
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
    await tester.pump();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(captured?.email, 'admin@example.com');
    expect(captured?.password, 'chosen-password');
  });

  testWidgets(
      'BACK falls back to the onboarding (ascii-art home) screen, not '
      'chats, when login screen is the router root (reachable server, '
      'not authenticated boots straight here) -- landing in chats with '
      'no session at all was a confirmed live auth-bypass',
      (tester) async {
    // Boot reaches this screen via context.goNamed (a stack replace), so
    // there is no previous route to pop back to.
    final router = GoRouter(
      initialLocation: AppRoutes.onboardingLogin,
      routes: [
        GoRoute(
          name: RouteNames.onboardingLogin,
          path: AppRoutes.onboardingLogin,
          builder: (_, __) => const SelfHostLoginScreen(),
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
    expect(find.text('SERVER CHOICE'), findsOneWidget);
  });
}
