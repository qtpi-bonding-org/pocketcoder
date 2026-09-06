import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_app_edition.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/settings/settings_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockMcpCubit extends Mock implements McpCubit {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockProDataDeletionHook extends Mock implements ProDataDeletionHook {}

class _FakeProEdition implements IAppEdition {
  const _FakeProEdition();
  @override
  bool get isPro => true;
}

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

class _FakeLocalSettingsService implements ILocalSettingsService {
  @override
  bool hapticsEnabledSync = true;
  @override
  Stream<bool> watchHapticsEnabled() => Stream.value(hapticsEnabledSync);
  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabledSync = enabled;
  }
}

AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SettingsScreen)))!;

void main() {
  late MockAuthRepository authRepo;
  late MockMcpCubit mcpCubit;
  late MockFlutterSecureStorage secureStorage;
  late MockProDataDeletionHook proDataDeletionHook;

  setUp(() {
    authRepo = MockAuthRepository();
    mcpCubit = MockMcpCubit();
    secureStorage = MockFlutterSecureStorage();
    proDataDeletionHook = MockProDataDeletionHook();
    when(() => mcpCubit.state).thenReturn(const McpState());
    when(() => mcpCubit.stream)
        .thenAnswer((_) => const Stream<McpState>.empty());
    when(() => secureStorage.readAll(
          aOptions: any(named: 'aOptions'),
          iOptions: any(named: 'iOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => {});

    getIt.registerFactory<AuthCubit>(() => AuthCubit(
          authRepo,
          CaddyCaPinStore(secureStorage),
          const NoopFactoryResetHook(),
          proDataDeletionHook,
          FossBillingService(),
          const _NoopServerReadinessCheck(),
        ));
    getIt.registerSingleton<IAppEdition>(const FossAppEdition());
    getIt.registerSingleton<ILocalSettingsService>(_FakeLocalSettingsService());
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => BlocProvider<McpCubit>.value(
            value: mcpCubit,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: AppRoutes.statusErrors,
          builder: (context, state) => const Text('errors-placeholder'),
        ),
      ],
    );

    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  testWidgets('tapping LOGOUT opens a confirm dialog; confirming calls logout',
      (tester) async {
    when(() => authRepo.logout()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('logout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    final signOutLabel = '<${l10nOf(tester).settingsLogoutConfirm}>';
    expect(find.text(signOutLabel), findsWidgets);

    await tester.tap(find.text(signOutLabel).last);
    await tester.pumpAndSettle();

    verify(() => authRepo.logout()).called(1);
  });

  testWidgets('tapping CANCEL does not call logout', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('logout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('<${l10nOf(tester).settingsLogoutCancel}>'));
    await tester.pumpAndSettle();

    verifyNever(() => authRepo.logout());
  });

  testWidgets(
      'tapping DELETE POCKETCODER PRO DATA opens a confirm dialog; '
      'confirming calls deleteProData', (tester) async {
    getIt.unregister<IAppEdition>();
    getIt.registerSingleton<IAppEdition>(const _FakeProEdition());
    when(() => proDataDeletionHook.deleteProData()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('delete pocketcoder pro data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('delete pocketcoder pro data'));
    await tester.pumpAndSettle();

    final deleteLabel = '<${l10nOf(tester).settingsDeleteProDataConfirm}>';
    expect(find.text(deleteLabel), findsWidgets);

    await tester.tap(find.text(deleteLabel).last);
    await tester.pumpAndSettle();

    verify(() => proDataDeletionHook.deleteProData()).called(1);
    // Unlike LOGOUT/RESET, a successful deleteProData must not navigate
    // away from Settings -- it never touches the local session.
    expect(find.text('delete pocketcoder pro data'), findsOneWidget);
  });

  testWidgets(
      'tapping CANCEL on the delete-pro-data dialog does not call '
      'deleteProData', (tester) async {
    getIt.unregister<IAppEdition>();
    getIt.registerSingleton<IAppEdition>(const _FakeProEdition());

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('delete pocketcoder pro data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('delete pocketcoder pro data'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.text('<${l10nOf(tester).settingsDeleteProDataCancel}>'));
    await tester.pumpAndSettle();

    verifyNever(() => proDataDeletionHook.deleteProData());
  });

  testWidgets('tapping ERROR REPORTS navigates to /configure/errors',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('error reports'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('error reports'));
    await tester.pumpAndSettle();

    expect(find.text('errors-placeholder'), findsOneWidget);
  });
}
