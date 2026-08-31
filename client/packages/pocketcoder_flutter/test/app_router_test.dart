import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';

void main() {
  tearDown(GetIt.instance.reset);

  test('serverControls resolves to a registered route in the base router',
      () {
    final router = AppRouter.router;
    final match = router.configuration.findMatch(
      Uri.parse(AppRoutes.serverControls),
    );
    expect(match.matches, isNotEmpty,
        reason:
            'MANAGE navigates to AppRoutes.serverControls -- it must resolve '
            'without a proprietary app injecting it via setAdditionalRoutes, '
            'since ServerControlScreen itself lives in the shared package');
  });

  testWidgets(
      'serverControls redirects to Configure when IServerControlService is '
      'not registered, instead of resolving to a route that would crash '
      'building ServerControlScreen', (tester) async {
    // Real route/redirect, placeholder destination (avoids full app DI).
    final realServerControlsRoute = AppRouter.router.configuration.routes
        .whereType<GoRoute>()
        .firstWhere((route) => route.path == AppRoutes.serverControls);

    final testRouter = GoRouter(
      initialLocation: AppRoutes.serverControls,
      routes: [
        realServerControlsRoute,
        GoRoute(
          path: AppRoutes.configure,
          builder: (_, __) => const Text('CONFIGURE PLACEHOLDER'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
    await tester.pumpAndSettle();

    expect(find.text('CONFIGURE PLACEHOLDER'), findsOneWidget);
  });
}
