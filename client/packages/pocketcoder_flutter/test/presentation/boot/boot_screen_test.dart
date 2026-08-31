import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/boot/boot_screen.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockInstanceExistenceResolver extends Mock
    implements IInstanceExistenceResolver {}

void main() {
  setUp(() {
    getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<(GoRouter, _MockAuthRepository)> pumpBootScreen(
    WidgetTester tester, {
    String? savedBaseUrl,
    AuthRefreshResult refreshResult = AuthRefreshResult.temporarilyUnavailable,
    bool isAuthenticated = true,
    IInstanceExistenceResolver? resolver,
  }) async {
    final authRepository = _MockAuthRepository();
    when(() => authRepository.authChanges)
        .thenAnswer((_) => const Stream<void>.empty());
    when(() => authRepository.isAuthenticated).thenReturn(isAuthenticated);
    when(() => authRepository.currentUserId).thenReturn('user-1');
    when(() => authRepository.currentBaseUrl).thenReturn('https://example.test');
    when(() => authRepository.getSavedBaseUrl())
        .thenAnswer((_) async => savedBaseUrl);
    when(() => authRepository.refreshToken())
        .thenAnswer((_) async => refreshResult);

    getIt.registerSingleton<IAuthRepository>(authRepository);
    getIt.registerSingleton(
      AuthSessionCoordinator(authRepository, refreshTimeout: Duration.zero),
    );
    if (resolver != null) {
      getIt.registerSingleton<IInstanceExistenceResolver>(resolver);
    }

    final router = GoRouter(
      initialLocation: '/boot',
      routes: [
        GoRoute(
          path: '/boot',
          name: RouteNames.boot,
          builder: (context, state) => BlocProvider(
            create: (_) => PocoCubit(),
            child: const BootScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.chats,
          name: RouteNames.home,
          builder: (context, state) => const Text('HOME ROUTE'),
        ),
        GoRoute(
          path: '/onboarding',
          name: RouteNames.onboarding,
          builder: (context, state) => const Text('ONBOARDING ROUTE'),
        ),
        GoRoute(
          path: '/onboarding/login',
          name: RouteNames.onboardingLogin,
          builder: (context, state) => const Text('LOGIN ROUTE'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      ),
    );
    return (router, authRepository);
  }

  Future<void> advancePastBootDelays(WidgetTester tester) async {
    // Wake-up (2.5s), Poco's connection check (4s), and the
    // connection-failure message display (3s).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  }

  testWidgets('no instance data routes to onboarding', (tester) async {
    final (router, authRepository) = await pumpBootScreen(
      tester,
      savedBaseUrl: null,
      isAuthenticated: false,
      refreshResult: AuthRefreshResult.invalidSession,
    );
    await advancePastBootDelays(tester);

    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    expect(find.text('ONBOARDING ROUTE'), findsOneWidget);
    verify(() => authRepository.getSavedBaseUrl()).called(1);
    // No instance data means the session must never even be consulted.
    verifyNever(() => authRepository.refreshToken());
  });

  testWidgets(
      'instance data present with a valid session routes straight to chats',
      (tester) async {
    final (router, authRepository) = await pumpBootScreen(
      tester,
      savedBaseUrl: 'https://example.test',
      isAuthenticated: true,
      refreshResult: AuthRefreshResult.refreshed,
    );
    await advancePastBootDelays(tester);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.chats);
    expect(find.text('HOME ROUTE'), findsOneWidget);
    verify(() => authRepository.getSavedBaseUrl()).called(1);
  });

  testWidgets(
      'instance data present but session cannot be restored routes to login',
      (tester) async {
    final (router, authRepository) = await pumpBootScreen(
      tester,
      savedBaseUrl: 'https://example.test',
      isAuthenticated: false,
      refreshResult: AuthRefreshResult.invalidSession,
    );
    await advancePastBootDelays(tester);

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.onboardingLogin,
    );
    expect(find.text('LOGIN ROUTE'), findsOneWidget);
    verify(() => authRepository.getSavedBaseUrl()).called(1);
  });

  testWidgets(
      'routes to onboarding when a temporarily unavailable session is stale',
      (tester) async {
    final resolver = _MockInstanceExistenceResolver();
    when(() => resolver.resolveStaleSessionIfInstanceGone())
        .thenAnswer((_) async => true);

    final (router, _) = await pumpBootScreen(
      tester,
      savedBaseUrl: 'https://example.test',
      isAuthenticated: true,
      resolver: resolver,
    );
    await advancePastBootDelays(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    expect(find.text('ONBOARDING ROUTE'), findsOneWidget);
    verify(() => resolver.resolveStaleSessionIfInstanceGone()).called(1);
  });

  testWidgets(
      'routes to home when stale-session resolution does not confirm a gone instance',
      (tester) async {
    final resolver = _MockInstanceExistenceResolver();
    when(() => resolver.resolveStaleSessionIfInstanceGone())
        .thenAnswer((_) async => false);

    final (router, _) = await pumpBootScreen(
      tester,
      savedBaseUrl: 'https://example.test',
      isAuthenticated: true,
      resolver: resolver,
    );
    await advancePastBootDelays(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.chats);
    expect(find.text('HOME ROUTE'), findsOneWidget);
    verify(() => resolver.resolveStaleSessionIfInstanceGone()).called(1);
  });
}
