import 'dart:io';

import 'package:cubit_ui_flow/cubit_ui_flow.dart' show IExceptionKeyMapper;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_decider.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/self_host_login_adapter.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockFactoryResetHook extends Mock implements FactoryResetHook {}

class _MockDeletionHook extends Mock implements ProDataDeletionHook {}

class _MockBillingService extends Mock implements BillingService {}

class _NoopServerReadinessCheck implements IServerReadinessCheck {
  const _NoopServerReadinessCheck();
  @override
  ServerReadinessSnapshot get current => const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned);
  @override
  Stream<ServerReadinessSnapshot> get readinessChanges => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> retry() async {}
}

void main() {
  testWidgets('successful login does not navigate from the adapter',
      (tester) async {
    final repository = _MockAuthRepository();
    final storage = _MockSecureStorage();
    final factoryResetHook = _MockFactoryResetHook();
    final deletionHook = _MockDeletionHook();
    final billing = _MockBillingService();
    when(() => repository.getSavedBaseUrl()).thenAnswer((_) async => null);
    when(() => repository.updateBaseUrl(any())).thenAnswer((_) async {});
    when(() => repository.verifyServerCompatibility()).thenAnswer((_) async {});
    when(() => repository.login(any(), any())).thenAnswer((_) async => true);
    when(() => repository.persistBaseUrl(any())).thenAnswer((_) async {});
    when(() => repository.authChanges)
        .thenAnswer((_) => const Stream<void>.empty());
    when(() => repository.isAuthenticated).thenReturn(false);
    when(() => repository.currentUserId).thenReturn(null);
    when(() => repository.currentBaseUrl).thenReturn(null);
    when(() => billing.reset()).thenAnswer((_) async {});
    when(() => factoryResetHook.resetForFactoryReset())
        .thenAnswer((_) async {});
    when(() => storage.readAll(
          aOptions: any(named: 'aOptions'),
          iOptions: any(named: 'iOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => {});

    final authCubit = AuthCubit(
        repository,
        CaddyCaPinStore(storage),
        factoryResetHook,
        deletionHook,
        billing,
        const _NoopServerReadinessCheck());
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, __) => BlocProvider.value(
            value: authCubit,
            child: SelfHostLoginAdapter(),
          ),
        ),
        GoRoute(
          path: '/harness',
          name: 'harness',
          builder: (_, __) => const Text('HARNESS'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      routerConfig: router,
    ));
    await tester.pump();
    await authCubit.login('https://server.test', 'user@test', 'password');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('HARNESS'), findsNothing);
  });

  group('post-success watchdog', () {
    late _MockAuthRepository repository;
    late AuthCubit authCubit;
    const watchdog = Duration(seconds: 10);

    setUp(() {
      repository = _MockAuthRepository();
      final storage = _MockSecureStorage();
      when(() => repository.getSavedBaseUrl()).thenAnswer((_) async => null);
      when(() => repository.updateBaseUrl(any())).thenAnswer((_) async {});
      when(() => repository.verifyServerCompatibility())
          .thenAnswer((_) async {});
      when(() => repository.login(any(), any())).thenAnswer((_) async => true);
      when(() => repository.persistBaseUrl(any())).thenAnswer((_) async {});
      authCubit = AuthCubit(
          repository,
          CaddyCaPinStore(storage),
          _MockFactoryResetHook(),
          _MockDeletionHook(),
          _MockBillingService(),
          const _NoopServerReadinessCheck());
    });

    tearDown(() async {
      await authCubit.close();
      if (GetIt.I.isRegistered<BootRoutingDecider>()) {
        await GetIt.I.unregister<BootRoutingDecider>();
      }
    });

    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: authCubit,
          child: SelfHostLoginAdapter(setupWatchdog: watchdog),
        ),
      ));
      await tester.pump();
      await authCubit.login('https://server.test', 'user@test', 'password');
      await tester.pump();
    }

    testWidgets('stays busy after success, then offers a boot retry',
        (tester) async {
      final decider = _MockBootRoutingDecider();
      when(() => decider.retryAuth()).thenAnswer((_) async {});
      GetIt.I.registerSingleton<BootRoutingDecider>(decider);
      await pumpLogin(tester);

      expect(find.text('connected, finishing setup…'), findsOneWidget);
      expect(find.text('retry'), findsNothing);

      await tester.pump(watchdog);
      await tester.pump(const Duration(seconds: 5));

      expect(
          find.textContaining('taking longer than expected',
              findRichText: true),
          findsOneWidget);
      await tester.tap(find.text('retry'));
      await tester.pump();

      verify(() => decider.retryAuth()).called(1);
      expect(find.text('connected, finishing setup…'), findsOneWidget);
    });

    testWidgets('retry without a boot decider does not crash', (tester) async {
      await pumpLogin(tester);
      await tester.pump(watchdog);

      await tester.tap(find.text('retry'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a new login failure resets the stalled screen to the form',
        (tester) async {
      await pumpLogin(tester);
      await tester.pump(watchdog);
      expect(find.text('retry'), findsOneWidget);

      when(() => repository.login(any(), any())).thenThrow(
          AuthException('login failed', ClientException(statusCode: 401)));
      await authCubit.login('https://server.test', 'user@test', 'password');
      await tester.pump();

      expect(find.text('retry'), findsNothing);
      expect(find.text('next'), findsOneWidget);
      await tester.pump(watchdog);
      expect(find.text('retry'), findsNothing);
    });
  });

  group('credential validation', () {
    late _MockAuthRepository repository;
    late AuthCubit authCubit;

    setUp(() {
      repository = _MockAuthRepository();
      when(() => repository.getSavedBaseUrl()).thenAnswer((_) async => null);
      when(() => repository.updateBaseUrl(any())).thenAnswer((_) async {});
      when(() => repository.verifyServerCompatibility())
          .thenAnswer((_) async {});
      when(() => repository.login(any(), any())).thenAnswer((_) async => true);
      when(() => repository.persistBaseUrl(any())).thenAnswer((_) async {});
      authCubit = AuthCubit(
          repository,
          CaddyCaPinStore(_MockSecureStorage()),
          _MockFactoryResetHook(),
          _MockDeletionHook(),
          _MockBillingService(),
          const _NoopServerReadinessCheck());
      authCubit.probeNetwork = (_) async => 'dns ok 5ms v4 192.155.89.165';
    });

    tearDown(() async {
      await authCubit.close();
      if (GetIt.I.isRegistered<IExceptionKeyMapper>()) {
        await GetIt.I.unregister<IExceptionKeyMapper>();
      }
    });

    Future<void> pumpForm(WidgetTester tester,
        {required String email,
        required String password,
        String? url = 'http://127.0.0.1:8090'}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: authCubit,
          child: SelfHostLoginAdapter(),
        ),
      ));
      await tester.pump();
      final fields = find.byType(EditableText);
      if (url != null) await tester.enterText(fields.at(0), url);
      await tester.enterText(fields.at(1), email);
      await tester.enterText(fields.at(2), password);
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.text('next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
        'the server URL starts empty -- a URL pasted into a prefilled '
        'default would be appended to it', (tester) async {
      await pumpForm(tester,
          email: 'user@example.com', password: 'password', url: null);

      final url = tester.widget<EditableText>(find.byType(EditableText).at(0));
      expect(url.controller.text, isEmpty);
    });

    testWidgets('an email with surrounding space is blocked inline',
        (tester) async {
      await pumpForm(tester, email: ' user@example.com', password: 'password');
      await submit(tester);

      expect(find.text('Remove leading/trailing whitespace'), findsOneWidget);
      verifyNever(() => repository.login(any(), any()));
    });

    testWidgets('a server URL without http(s):// is blocked inline',
        (tester) async {
      await pumpForm(tester, email: 'user@example.com', password: 'password');
      await tester.enterText(
          find.byType(EditableText).at(0), '192-155-89-165.sslip.io');
      await tester.pump();
      await submit(tester);

      expect(find.text('Start with http:// or https://'), findsOneWidget);
      verifyNever(() => repository.login(any(), any()));
    });

    testWidgets('a malformed email is blocked inline', (tester) async {
      await pumpForm(tester, email: 'user@localhost', password: 'password');
      await submit(tester);

      expect(find.text('Enter a valid email address'), findsOneWidget);
      verifyNever(() => repository.login(any(), any()));
    });

    testWidgets('mixed-case email and spaced password are sent verbatim',
        (tester) async {
      await pumpForm(tester,
          email: 'User.Name@Example.com', password: ' pass word ');

      expect(
          find.textContaining('Has leading/trailing whitespace',
              findRichText: true),
          findsOneWidget);
      await submit(tester);

      verify(() => repository.login('User.Name@Example.com', ' pass word '))
          .called(1);
    });

    testWidgets('a clean password shows no paste warning', (tester) async {
      await pumpForm(tester, email: 'user@example.com', password: 'pa ss');

      expect(
          find.textContaining('Has leading/trailing whitespace',
              findRichText: true),
          findsNothing);
    });

    testWidgets(
        'a failed login says what failed and names the host it tried, so '
        'a screenshot alone is diagnosable', (tester) async {
      GetIt.I.registerSingleton<IExceptionKeyMapper>(AppExceptionKeyMapper());
      when(() => repository.login(any(), any())).thenThrow(AuthException(
          'login failed',
          ClientException(
              originalError:
                  const SocketException("Failed host lookup: 'review.test'"))));
      await pumpForm(tester,
          email: 'user@example.com',
          password: 'password',
          url: 'https://review.test');
      await submit(tester);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('auth.server.dns', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Tried: review.test', findRichText: true),
          findsOneWidget);
    });

    testWidgets(
        'a network failure shows the hop-by-hop probe result under the '
        'error, so one screenshot names the broken hop', (tester) async {
      GetIt.I.registerSingleton<IExceptionKeyMapper>(AppExceptionKeyMapper());
      when(() => repository.login(any(), any())).thenThrow(AuthException(
          'login failed',
          ClientException(
              originalError:
                  const SocketException("Failed host lookup: 'review.test'"))));
      await pumpForm(tester,
          email: 'user@example.com',
          password: 'password',
          url: 'https://review.test');
      await submit(tester);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('dns ok 5ms', findRichText: true),
          findsOneWidget);
    });

    testWidgets(
        'leaving a field empty leaves a message on screen, not only a '
        'toast that disappears', (tester) async {
      await pumpForm(tester, email: 'user@example.com', password: '');
      await submit(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(
          find.textContaining('enter all required fields', findRichText: true),
          findsOneWidget);
      verifyNever(() => repository.login(any(), any()));
    });

    testWidgets('rejected credentials explain that matching is exact',
        (tester) async {
      GetIt.I.registerSingleton<IExceptionKeyMapper>(AppExceptionKeyMapper());
      when(() => repository.login(any(), any())).thenThrow(
          AuthException('login failed', ClientException(statusCode: 400)));
      await pumpForm(tester, email: 'user@example.com', password: 'password');
      await submit(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(
          find.textContaining('Capitals and whitespace count',
              findRichText: true),
          findsOneWidget);
    });
  });
}

class _MockBootRoutingDecider extends Mock implements BootRoutingDecider {}
