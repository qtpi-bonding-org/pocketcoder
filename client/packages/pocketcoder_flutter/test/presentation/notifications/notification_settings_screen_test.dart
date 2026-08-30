// Widget tests for NotificationSettingsScreen.
//
// Mirrors `settings_screen_test.dart`'s MockMcpCubit pattern: a mocked
// cubit (MockNotificationRuleCubit extends Mock implements
// NotificationRuleCubit) registered into `getIt`, since the screen builds
// its own BlocProvider internally via `getIt<NotificationRuleCubit>()`
// (mirroring how SettingsScreen registers its own AuthCubit). A MaterialApp
// sets `theme: AppTheme.lightTheme` so the screen's context.colorScheme
// lookups don't crash during the test.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/notifications/notification_settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';

class MockNotificationRuleCubit extends Mock implements NotificationRuleCubit {}

class FakePushService implements PushService {
  int configureCalls = 0;

  @override
  Future<void> configure() async {
    configureCalls += 1;
  }

  @override
  Future<PushNotificationPayload?> getInitialNotification() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<PushNotificationPayload> get notificationStream =>
      const Stream.empty();

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> syncAuthenticatedDevice() async {}

  @override
  Future<void> unregisterAuthenticatedDevice() async {}
}

Widget _wrap() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const NotificationSettingsScreen(),
  );
}

void main() {
  late MockNotificationRuleCubit cubit;
  late FakePushService pushService;

  setUp(() {
    cubit = MockNotificationRuleCubit();
    pushService = FakePushService();
    when(() => cubit.watchRules()).thenReturn(null);
    when(() => cubit.setTypeEnabled(any(), any())).thenAnswer((_) async {});
    when(() => cubit.state)
        .thenReturn(const NotificationRuleState(status: UiFlowStatus.success));
    when(() => cubit.stream)
        .thenAnswer((_) => const Stream<NotificationRuleState>.empty());
    when(() => cubit.close()).thenAnswer((_) async {});

    // NotificationSettingsScreen creates its own BlocProvider internally via
    // getIt<NotificationRuleCubit>() (see the screen's build method) rather
    // than reading one from an ancestor — matches SettingsScreen's own
    // AuthCubit registration precedent in settings_screen_test.dart. Register
    // the mock into getIt instead of wrapping the screen in an external
    // BlocProvider.value, which would conflict with the screen's own.
    getIt.registerFactory<NotificationRuleCubit>(() => cubit);
    getIt.registerSingleton<PushService>(pushService);
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets(
      'renders four switches with default-on values when the rules map is empty',
      (tester) async {
    when(() => cubit.state)
        .thenReturn(const NotificationRuleState(status: UiFlowStatus.success));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('CHAT REPLIES'), findsOneWidget);
    expect(find.text('SCHEDULED TASKS'), findsOneWidget);
    expect(find.text('TASK COMPLETE'), findsOneWidget);
    expect(find.text('TASK ERRORS'), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(tester.widget<Switch>(switches.at(i)).value, isTrue);
    }
    expect(find.byType(BiosRow), findsNWidgets(4));
  });

  testWidgets('honors a non-default value from the loaded rules map',
      (tester) async {
    when(() => cubit.state).thenReturn(const NotificationRuleState(
      status: UiFlowStatus.success,
      rules: {
        'chat_reply': false,
        'schedule': true,
        'task_complete': true,
        'task_error': false,
      },
    ));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(4));
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse); // chat_reply
    expect(tester.widget<Switch>(switches.at(1)).value, isTrue); // schedule
    expect(
        tester.widget<Switch>(switches.at(2)).value, isTrue); // task_complete
    expect(tester.widget<Switch>(switches.at(3)).value, isFalse); // task_error
  });

  testWidgets('tapping a switch calls cubit.setTypeEnabled with the right args',
      (tester) async {
    when(() => cubit.state)
        .thenReturn(const NotificationRuleState(status: UiFlowStatus.success));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Tap the first switch (chat_reply) — flips it off.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    verify(() => cubit.setTypeEnabled('chat_reply', false)).called(1);
  });

  testWidgets('has no PocoBubble -- this is a plain settings screen',
      (tester) async {
    when(() => cubit.state)
        .thenReturn(const NotificationRuleState(status: UiFlowStatus.success));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(PocoBubble), findsNothing);
  });

  testWidgets(
      'shows the self-hosted push option, reachable regardless of edition, '
      'and tapping configure calls PushService.configure()', (tester) async {
    when(() => cubit.state)
        .thenReturn(const NotificationRuleState(status: UiFlowStatus.success));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.proSelfHostedPushTitle), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.proConfigureSelfHostedPush));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.proConfigureSelfHostedPush));
    await tester.pumpAndSettle();

    expect(pushService.configureCalls, 1);
  });
}
