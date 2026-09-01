import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/boot/boot_screen.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  setUp(() => getIt.reset());
  tearDown(() async => getIt.reset());

  testWidgets('keeps presentation on boot without deciding a destination',
      (tester) async {
    final authRepository = _MockAuthRepository();
    when(() => authRepository.authChanges)
        .thenAnswer((_) => const Stream<void>.empty());
    when(() => authRepository.isAuthenticated).thenReturn(false);
    when(() => authRepository.currentUserId).thenReturn(null);
    when(() => authRepository.currentBaseUrl).thenReturn(null);
    when(() => authRepository.getSavedBaseUrl())
        .thenAnswer((_) async => 'https://example.test');
    when(() => authRepository.refreshToken())
        .thenAnswer((_) async => AuthRefreshResult.invalidSession);
    getIt.registerSingleton<IAuthRepository>(authRepository);

    final router = GoRouter(
      initialLocation: '/boot',
      routes: [
        GoRoute(
          path: '/boot',
          name: 'boot',
          builder: (context, state) => BlocProvider(
            create: (_) => PocoCubit(),
            child: const BootScreen(),
          ),
        ),
        GoRoute(
          path: '/destination',
          name: 'destination',
          builder: (_, __) => const Text('DESTINATION'),
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

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/boot');
    verifyNever(() => authRepository.getSavedBaseUrl());
    verifyNever(() => authRepository.refreshToken());
  });
}
