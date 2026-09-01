import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:acp_dart/acp_dart.dart' hide PermissionOption;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondPermissionCalls = [];
  final List<Map<String, Object?>> respondElicitationCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Stream<List<BaseEvent>> watchRawEvents(String chatId) => const Stream.empty();

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<int> ingestOnce(String chatId, {required int cursor}) async => 0;

  @override
  Future<void> cancelStreams() async {}

  @override
  Future<String> sendPrompt(String chatId, String text,
      {String? messageId}) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) async {}

  @override
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) async {
    respondPermissionCalls.add({
      'chatId': chatId,
      'requestId': requestId,
      'optionId': optionId,
      'cancelled': cancelled,
    });
  }

  @override
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) async {
    respondElicitationCalls.add({
      'chatId': chatId,
      'elicitationId': elicitationId,
      'resp': resp,
    });
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  group('PermissionCard', () {
    late _FakeAgentChatRepository repo;
    late PermissionCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = PermissionCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders pending permission; tapping allow calls authorize(optionId)',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<PermissionCubit>.value(
            value: cubit,
            child: PermissionCard(
              onSelect: (requestId, {optionId, cancelled = false}) {
                if (cancelled || optionId == null) {
                  cubit.deny();
                } else {
                  cubit.authorize(optionId);
                }
              },
              item: PermissionRequestTimelineItem(
                requestId: 'req-1',
                toolTitle: 'run shell',
                order: const OrderKey(1),
                options: [
                  PermissionOption(
                    optionId: 'allow-once',
                    label: 'Allow Once',
                    kind: 'allow_once',
                  ),
                ],
              ),
            ),
          ),
        ));
        await _settle(tester);

        // PermissionCard no longer reads display data from the cubit, but
        // authorize()/deny() still resolve their requestId from the cubit's
        // own state internally — seed it so the action call has somewhere
        // to read a matching requestId from.
        cubit.open('chat-1');
        await _settle(tester);
        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(
                permission: {'requestId': 'req-1', 'status': 'pending'},
              ),
            ));
        await _settle(tester);

        expect(find.text('run shell'), findsOneWidget);
        expect(find.text('ALLOW ONCE'), findsOneWidget);

        await tester.tap(find.text('ALLOW ONCE').last);
        await _settle(tester);

        expect(repo.respondPermissionCalls, hasLength(1));
        expect(repo.respondPermissionCalls.single['requestId'], 'req-1');
        expect(repo.respondPermissionCalls.single['optionId'], 'allow-once');
        expect(repo.respondPermissionCalls.single['cancelled'], false);
      },
    );

    testWidgets('tapping deny calls respondPermission with cancelled:true',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<PermissionCubit>.value(
          value: cubit,
          child: PermissionCard(
            onSelect: (requestId, {optionId, cancelled = false}) {
              if (cancelled || optionId == null) {
                cubit.deny();
              } else {
                cubit.authorize(optionId);
              }
            },
            item: PermissionRequestTimelineItem(
              requestId: 'req-2',
              order: const OrderKey(1),
              options: const [],
            ),
          ),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);
      repo.controllerFor('chat-1').add(Conversation(
            sessionState: SessionState(
              permission: {'requestId': 'req-2', 'status': 'pending'},
            ),
          ));
      await _settle(tester);

      // Regression check: this item has no toolTitle and no description
      // (a real, observed shape -- goose omits ACP's optional
      // ToolCallUpdate.Title for some tool calls). Without a fallback the
      // card showed nothing at all to say what permission was even being
      // asked for, just its own internal request id in tiny gray text.
      expect(find.text('Permission requested'), findsOneWidget);

      await tester.tap(find.text('DENY'));
      await _settle(tester);

      expect(repo.respondPermissionCalls, hasLength(1));
      expect(repo.respondPermissionCalls.single['requestId'], 'req-2');
      expect(repo.respondPermissionCalls.single['cancelled'], true);
    });

    testWidgets(
        'option buttons are outlined, not filled -- reject options use the '
        'warning color, allow options use primary', (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<PermissionCubit>.value(
          value: cubit,
          child: PermissionCard(
            onSelect: (_, {optionId, cancelled = false}) {},
            item: PermissionRequestTimelineItem(
              requestId: 'req-3',
              order: const OrderKey(1),
              options: const [
                PermissionOption(
                    optionId: 'allow', label: 'Allow Once', kind: 'allow_once'),
                PermissionOption(
                    optionId: 'reject',
                    label: 'Reject Once',
                    kind: 'reject_once'),
              ],
            ),
          ),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);
      repo.controllerFor('chat-1').add(Conversation(
            sessionState: SessionState(
              permission: {'requestId': 'req-3', 'status': 'pending'},
            ),
          ));
      await _settle(tester);

      final allowButton = tester.widget<TerminalButton>(
          find.widgetWithText(TerminalButton, 'ALLOW ONCE'));
      final rejectButton = tester.widget<TerminalButton>(
          find.widgetWithText(TerminalButton, 'REJECT ONCE'));

      expect(allowButton.filled, isFalse);
      expect(rejectButton.filled, isFalse);
      expect(allowButton.color, isNot(rejectButton.color));

      final context = tester.element(find.byType(PermissionCard));
      expect(rejectButton.color, context.terminalColors.warning);
      expect(allowButton.color, context.colorScheme.primary);
    });
  });
}
