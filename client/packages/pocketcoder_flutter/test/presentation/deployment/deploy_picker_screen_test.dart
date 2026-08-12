import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';

class FakeDeployOptionService implements IDeployOptionService {
  @override
  List<DeployOption> getAvailableProviders() => const [
        DeployOption(
          id: 'linode',
          name: 'Linode (Akamai)',
          description: 'One-tap deploy via OAuth. 24h access included.',
          routePath: '/auth',
          requiresPro: true,
        ),
        DeployOption(
          id: 'elestio',
          name: 'Elestio',
          description: 'Managed hosting integration is not supported yet.',
          availability: DeployOptionAvailability.comingSoon,
        ),
      ];
}

void main() {
  setUp(() {
    GetIt.I
        .registerFactory<IDeployOptionService>(() => FakeDeployOptionService());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('forwards credentials as extra when a provider card is tapped',
      (tester) async {
    String? capturedRoute;
    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/deploy',
      routes: [
        GoRoute(
          path: '/deploy',
          builder: (context, state) => DeployPickerScreen(
            credentials: DeployCredentials(
              email: 'reviewer@example.com',
              password: 'test-pass',
            ),
            deployOptionService: FakeDeployOptionService(),
            onHasProAccess: () async => true,
          ),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) {
            capturedRoute = state.uri.toString();
            capturedExtra = state.extra;
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

    await tester.tap(find.textContaining('LINODE'));
    await tester.pumpAndSettle();

    expect(capturedRoute, '/auth');
    expect(capturedExtra, isA<DeployCredentials>());
    expect((capturedExtra as DeployCredentials).email, 'reviewer@example.com');
  });

  testWidgets('shows coming-soon providers dimmed and disables selection',
      (tester) async {
    var selectionChecks = 0;
    final router = GoRouter(
      initialLocation: '/deploy',
      routes: [
        GoRoute(
          path: '/deploy',
          builder: (context, state) => DeployPickerScreen(
            deployOptionService: FakeDeployOptionService(),
            onHasProAccess: () async {
              selectionChecks += 1;
              return true;
            },
          ),
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

    expect(find.text('COMING SOON'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.textContaining('ELESTIO'),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.42);

    await tester.tap(find.textContaining('ELESTIO'));
    await tester.pump();
    expect(selectionChecks, 0);
  });
}
