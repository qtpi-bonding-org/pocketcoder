import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/server_credentials.dart';
import 'package:pocketcoder_flutter/presentation/deployment/choose_provider_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class FakeProviderOptionService implements IProviderOptionService {
  @override
  List<ProviderOption> getAvailableProviders() => const [
        ProviderOption(
          id: 'linode',
          name: 'Linode (Akamai)',
          description: 'One-tap deploy via OAuth. 24h access included.',
          routePath: '/auth',
          requiresPro: true,
        ),
        ProviderOption(
          id: 'elestio',
          name: 'Elestio',
          description: 'Managed hosting integration is not supported yet.',
          availability: ProviderOptionAvailability.comingSoon,
        ),
      ];
}

void main() {
  setUp(() {
    GetIt.I.registerFactory<IProviderOptionService>(
        () => FakeProviderOptionService());
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
          builder: (context, state) => ChooseProviderScreen(
            credentials: ServerCredentials(
              email: 'reviewer@example.com',
              password: 'test-pass',
            ),
            deployOptionService: FakeProviderOptionService(),
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

    expect(find.byType(TerminalFooter), findsOneWidget);

    await tester.tap(find.textContaining('Linode'));
    await tester.pumpAndSettle();

    expect(capturedRoute, '/auth');
    expect(capturedExtra, isA<ServerCredentials>());
    expect((capturedExtra as ServerCredentials).email, 'reviewer@example.com');
  });

  testWidgets('sends onboarding to credentials after provider selection',
      (tester) async {
    ProviderOption? selectedProvider;
    final router = GoRouter(
      initialLocation: '/deploy',
      routes: [
        GoRoute(
          path: '/deploy',
          builder: (context, state) => ChooseProviderScreen(
            deployOptionService: FakeProviderOptionService(),
            onHasProAccess: () async => true,
          ),
        ),
        GoRoute(
          name: RouteNames.onboardingDeploy,
          path: AppRoutes.onboardingDeploy,
          builder: (context, state) {
            selectedProvider = state.extra as ProviderOption?;
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

    await tester.tap(find.textContaining('Linode'));
    await tester.pumpAndSettle();

    expect(selectedProvider?.id, 'linode');
    expect(selectedProvider?.routePath, '/auth');
  });

  testWidgets('shows coming-soon providers dimmed and disables selection',
      (tester) async {
    var selectionChecks = 0;
    final router = GoRouter(
      initialLocation: '/deploy',
      routes: [
        GoRoute(
          path: '/deploy',
          builder: (context, state) => ChooseProviderScreen(
            deployOptionService: FakeProviderOptionService(),
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

    final unavailable = tester.widget<TerminalText>(
      find.byWidgetPredicate(
        (widget) => widget is TerminalText && widget.text.contains('Elestio'),
      ),
    );
    expect(unavailable.text, contains('COMING SOON'));
    // Unavailable providers should use a de-emphasized role
    // Check that the rendered Text widget has the label role's color
    final unavailableText = tester.widget<Text>(
      find.descendant(
          of: find.byWidget(unavailable), matching: find.byType(Text)),
    );
    expect(unavailableText.style?.color, TextRole.label.color);

    await tester.tap(find.textContaining('Elestio'));
    await tester.pump();
    expect(selectionChecks, 0);
  });
}
