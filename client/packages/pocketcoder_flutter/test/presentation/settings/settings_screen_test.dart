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
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/settings/settings_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockMcpCubit extends Mock implements McpCubit {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRepository authRepo;
  late MockMcpCubit mcpCubit;
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    authRepo = MockAuthRepository();
    mcpCubit = MockMcpCubit();
    secureStorage = MockFlutterSecureStorage();
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
        ));
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
          path: AppRoutes.configureErrors,
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
      find.text('LOGOUT'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOGOUT'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN OUT'), findsWidgets);

    await tester.tap(find.text('SIGN OUT').last);
    await tester.pumpAndSettle();

    verify(() => authRepo.logout()).called(1);
  });

  testWidgets('tapping CANCEL does not call logout', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('LOGOUT'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOGOUT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    verifyNever(() => authRepo.logout());
  });

  testWidgets('tapping ERROR REPORTS navigates to /configure/errors',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('ERROR REPORTS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR REPORTS'));
    await tester.pumpAndSettle();

    expect(find.text('errors-placeholder'), findsOneWidget);
  });
}
