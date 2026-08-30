import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  testWidgets(
      'BACK renders leftmost in the footer, ahead of contextual actions; '
      'nav pillars are hidden on a showBack sub-screen by default',
      (tester) async {
    await tester.pumpWidget(wrap(PocketCoderShell(
      title: 'CHAT',
      activePillar: NavPillar.chats,
      showBack: true,
      actions: [TerminalAction(label: 'FILES', onTap: () {})],
      body: const SizedBox.shrink(),
    )));

    final labels = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(TerminalFooter), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();

    final back = labels.indexOf('BACK');
    final files = labels.indexOf('FILES');
    expect(back, 0);
    expect(files, greaterThan(back));
    expect(labels, isNot(contains('CHATS')));
  });

  Future<GoRouter> pumpRouterAt(
    WidgetTester tester, {
    required String initialLocation,
    String? backFallbackRoute,
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.chats,
          name: RouteNames.chats,
          builder: (_, __) => const Scaffold(body: Text('CHATS SCREEN')),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          name: RouteNames.onboarding,
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING SCREEN')),
        ),
        GoRoute(
          path: '/current',
          builder: (_, __) => PocketCoderShell(
            title: 'CURRENT',
            activePillar: NavPillar.chats,
            showBack: true,
            backFallbackRoute: backFallbackRoute,
            body: const SizedBox.shrink(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();
    return router;
  }

  testWidgets(
      'with no backFallbackRoute override and nothing to pop, BACK lands '
      'on the authenticated home -- the safe default for an in-app screen '
      'reached via a stack replace (e.g. a freshly-onboarded first chat)',
      (tester) async {
    await pumpRouterAt(tester, initialLocation: '/current');

    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(find.text('CHATS SCREEN'), findsOneWidget);
  });

  testWidgets(
      'with backFallbackRoute set and nothing to pop, BACK honors it -- '
      'a pre-auth screen must never fall back to the authenticated home',
      (tester) async {
    await pumpRouterAt(
      tester,
      initialLocation: '/current',
      backFallbackRoute: AppRoutes.onboarding,
    );

    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING SCREEN'), findsOneWidget);
  });
}
