import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/self_host_login_adapter.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockFactoryResetHook extends Mock implements FactoryResetHook {}

class _MockDeletionHook extends Mock implements ProDataDeletionHook {}

class _MockBillingService extends Mock implements BillingService {}

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

    final authCubit = AuthCubit(repository, CaddyCaPinStore(storage),
        factoryResetHook, deletionHook, billing, const _NoopServerReadinessCheck());
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
}
