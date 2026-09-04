import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

class _FakeLocalSettingsService implements ILocalSettingsService {
  _FakeLocalSettingsService({this.hapticsEnabledSync = true});

  @override
  bool hapticsEnabledSync;

  @override
  Stream<bool> watchHapticsEnabled() => Stream.value(hapticsEnabledSync);

  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabledSync = enabled;
  }
}

class _FakeServerControlService implements IServerControlService {
  @override
  Future<String?> readPublicKey({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<String?> readPrivateKey({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerReleaseStatusSnapshot> inspectRelease() =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> restartPocketCoder(
          {required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> updatePocketCoder({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> restartNixOs({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> updateNixOs({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> saveBackup({required String instanceId}) =>
      throw UnimplementedError();

  @override
  Future<ServerControlResult> restoreBackup({required String instanceId}) =>
      throw UnimplementedError();
}

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

  testWidgets(
      'MANAGE appears in the footer when IServerControlService is '
      'registered, and is absent otherwise', (tester) async {
    final getIt = GetIt.instance;
    addTearDown(getIt.reset);

    await tester.pumpWidget(wrap(PocketCoderShell(
      title: 'CONFIGURE',
      activePillar: NavPillar.configure,
      body: const SizedBox.shrink(),
    )));
    expect(find.text('MANAGE'), findsNothing);

    getIt.registerLazySingleton<IServerControlService>(
      () => _FakeServerControlService(),
    );
    await tester.pumpWidget(wrap(PocketCoderShell(
      title: 'CONFIGURE',
      activePillar: NavPillar.configure,
      body: const SizedBox.shrink(),
    )));
    expect(find.text('MANAGE'), findsOneWidget);
  });

  group('nav-tap haptics', () {
    final haptics = <MethodCall>[];

    setUp(() {
      haptics.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      GetIt.instance.reset();
    });

    Future<void> pumpPillarRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.chats,
        routes: [
          GoRoute(
            path: AppRoutes.chats,
            name: RouteNames.chats,
            builder: (_, __) => PocketCoderShell(
              title: 'CHATS',
              activePillar: NavPillar.chats,
              body: const SizedBox.shrink(),
            ),
          ),
          GoRoute(
            path: AppRoutes.monitor,
            name: RouteNames.monitor,
            builder: (_, __) => PocketCoderShell(
              title: 'MONITOR',
              activePillar: NavPillar.monitor,
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
    }

    testWidgets('fires when switching pillars and the setting is enabled',
        (tester) async {
      GetIt.instance.registerSingleton<ILocalSettingsService>(
          _FakeLocalSettingsService(hapticsEnabledSync: true));
      await pumpPillarRouter(tester);

      await tester.tap(find.text('MONITOR'));
      await tester.pumpAndSettle();

      expect(haptics, hasLength(1));
    });

    testWidgets('does not fire when the setting is disabled', (tester) async {
      GetIt.instance.registerSingleton<ILocalSettingsService>(
          _FakeLocalSettingsService(hapticsEnabledSync: false));
      await pumpPillarRouter(tester);

      await tester.tap(find.text('MONITOR'));
      await tester.pumpAndSettle();

      expect(haptics, isEmpty);
    });

    testWidgets('does not fire when re-tapping the already-active pillar',
        (tester) async {
      GetIt.instance.registerSingleton<ILocalSettingsService>(
          _FakeLocalSettingsService(hapticsEnabledSync: true));
      await pumpPillarRouter(tester);

      await tester.tap(find.descendant(
          of: find.byType(TerminalFooter), matching: find.text('CHATS')));
      await tester.pumpAndSettle();

      expect(haptics, isEmpty);
    });
  });
}
