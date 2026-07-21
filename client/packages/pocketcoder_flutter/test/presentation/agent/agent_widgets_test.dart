// Widget tests for the presentation/agent/ widgets (plan Task 13 Step 4).
// Pumps each widget with a directly-instantiated cubit fed by a fake
// AgentChatRepository (the same pattern used by the application/agent/
// cubit tests), asserts it renders the relevant state slice, and that a
// tap routes through to the cubit method. Light per-widget coverage — one
// or two assertions per behavior.
import 'dart:async';

import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/elicitation_form.dart';
import 'package:pocketcoder_flutter/presentation/agent/mode_switcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/permission_prompt.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondPermissionCalls = [];
  final List<Map<String, Object?>> respondElicitationCalls = [];
  final List<Map<String, Object?>> setModeCalls = [];
  final List<Map<String, Object?>> setConfigOptionCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<void> ingestOnce(String chatId, {required int cursor}) async {}

  @override
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {
    setModeCalls.add({'chatId': chatId, 'modeId': modeId});
  }

  @override
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) async {
    setConfigOptionCalls.add({'chatId': chatId, 'req': req});
  }

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
    // Scaffold (not just a bare Material) so widgets that need both a
    // Material ancestor (Switch, InkResponse/GestureDetector ink splashes)
    // and unconstrained vertical space (Column/ListView inside these
    // widgets) get real layout constraints instead of the tight/zero-size
    // constraints `home: child` alone would hand them directly under
    // MaterialApp.
    home: Scaffold(body: child),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  group('ModeSwitcher', () {
    late _FakeAgentChatRepository repo;
    late SessionControlsCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = SessionControlsCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets('renders availableModes and tapping one calls selectMode',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<SessionControlsCubit>.value(
          value: cubit,
          child: const ModeSwitcher(),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);

      repo.controllerFor('chat-1').add(Conversation(
            sessionState: SessionState(modes: {
              'currentModeId': 'auto',
              'availableModes': [
                {'id': 'auto', 'name': 'Auto'},
                {'id': 'chat', 'name': 'Chat'},
              ],
            }),
          ));
      await _settle(tester);

      expect(find.text('AUTO'), findsOneWidget);
      expect(find.text('CHAT'), findsOneWidget);

      await tester.tap(find.text('CHAT'));
      await _settle(tester);

      expect(repo.setModeCalls, [
        {'chatId': 'chat-1', 'modeId': 'chat'},
      ]);
    });
  });

  group('ConfigPicker', () {
    late _FakeAgentChatRepository repo;
    late SessionControlsCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = SessionControlsCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders boolean + select options; flipping a boolean calls setOption',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<SessionControlsCubit>.value(
            value: cubit,
            child: const ConfigPicker(),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(config: {
                'options': [
                  {
                    'kind': 'boolean',
                    'id': 'auto-approve',
                    'name': 'Auto Approve',
                    'currentValue': false,
                  },
                  {
                    'kind': 'select',
                    'id': 'preset',
                    'name': 'Preset',
                    'currentValue': 'safe',
                    'options': [
                      {'value': 'safe', 'label': 'Safe'},
                      {'value': 'fast', 'label': 'Fast'},
                    ],
                  },
                ],
              }),
            ));
        await _settle(tester);

        expect(find.text('AUTO APPROVE'), findsOneWidget);
        expect(find.text('PRESET'), findsOneWidget);

        await tester.tap(find.byType(Switch));
        await _settle(tester);

        expect(repo.setConfigOptionCalls, hasLength(1));
        expect(repo.setConfigOptionCalls.single['chatId'], 'chat-1');
        final req =
            repo.setConfigOptionCalls.single['req'] as SetSessionConfigOptionRequest;
        expect(req.configId, 'auto-approve');
        expect(req.value, 'true');
      },
    );
  });

  group('ElicitationForm', () {
    late _FakeAgentChatRepository repo;
    late ElicitationCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = ElicitationCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders the form for a pending elicitation; submit calls respondElicitation',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<ElicitationCubit>.value(
            value: cubit,
            child: const ElicitationForm(),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(elicitation: {
                'elicitationId': 'elic-1',
                'message': 'Pick a value',
                'requestedSchema': {
                  'type': 'object',
                  'properties': {
                    'color': {'type': 'string', 'title': 'Color'},
                  },
                },
              }),
            ));
        await _settle(tester);

        expect(find.text('Pick a value'), findsOneWidget);
        expect(find.text('SUBMIT'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'blue');
        await tester.tap(find.text('SUBMIT'));
        await _settle(tester);

        expect(repo.respondElicitationCalls, hasLength(1));
        expect(repo.respondElicitationCalls.single['elicitationId'], 'elic-1');
        final resp = repo.respondElicitationCalls.single['resp']
            as ElicitationResponse;
        expect(resp.toJson(), {
          'action': 'accept',
          'content': {'color': 'blue'},
        });
      },
    );

    testWidgets('renders nothing when no elicitation is pending',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<ElicitationCubit>.value(
          value: cubit,
          child: const ElicitationForm(),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);

      expect(find.text('SUBMIT'), findsNothing);
    });
  });

  group('PermissionPrompt', () {
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
            child: const PermissionPrompt(),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(permission: {
                'requestId': 'req-1',
                'toolCall': {'title': 'run shell'},
                'options': [
                  {
                    'optionId': 'allow-once',
                    'name': 'Allow Once',
                    'kind': 'allow_once',
                  },
                ],
              }),
            ));
        await _settle(tester);

        expect(find.text('run shell'), findsOneWidget);
        expect(find.text('ALLOW ONCE'), findsOneWidget);

        await tester.tap(find.text('AUTHORIZE').last);
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
          child: const PermissionPrompt(),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);

      repo.controllerFor('chat-1').add(Conversation(
            sessionState: SessionState(permission: {
              'requestId': 'req-2',
              'options': [
                {'optionId': 'allow-once', 'name': 'Allow', 'kind': 'allow'},
              ],
            }),
          ));
      await _settle(tester);

      await tester.tap(find.text('DENY'));
      await _settle(tester);

      expect(repo.respondPermissionCalls, hasLength(1));
      expect(repo.respondPermissionCalls.single['requestId'], 'req-2');
      expect(repo.respondPermissionCalls.single['cancelled'], true);
    });
  });
}
