import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
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
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

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
  }) async {}

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
  group('ElicitationCard', () {
    late _FakeAgentChatRepository repo;
    late ElicitationCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = ElicitationCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    const item = ElicitationRequestTimelineItem(
      requestId: 'elic-1',
      message: 'Pick a value',
      mode: 'form',
      order: OrderKey(1),
      schema: {
        'type': 'object',
        'properties': {
          'color': {'type': 'string', 'title': 'Color'},
        },
      },
    );

    testWidgets(
      'renders the form for the given item; submit calls respondElicitation',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<ElicitationCubit>.value(
            value: cubit,
            child: ElicitationCard(
              item: item,
              onRespond: (requestId, response) {
                final action = response['action'] as String?;
                final content = response['content'];
                final elicitationResponse = switch (action) {
                  'accept' => ElicitationResponse.accept(
                      content is Map
                          ? Map<String, dynamic>.from(content)
                          : const <String, dynamic>{},
                    ),
                  'decline' => const ElicitationResponse.decline(),
                  _ => const ElicitationResponse.cancel(),
                };
                cubit.submit(elicitationResponse);
              },
            ),
          ),
        ));
        await _settle(tester);

        // ElicitationCard no longer reads display data from the cubit, but
        // submit() still resolves its elicitationId from the cubit's own
        // state internally — seed it so the action call has a match.
        cubit.open('chat-1');
        await _settle(tester);
        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(
                elicitation: {'elicitationId': 'elic-1'},
              ),
            ));
        await _settle(tester);

        expect(find.text('Pick a value'), findsOneWidget);
        expect(find.text('SUBMIT'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'blue');
        await tester.tap(find.text('SUBMIT'));
        await _settle(tester);

        expect(repo.respondElicitationCalls, hasLength(1));
        expect(repo.respondElicitationCalls.single['elicitationId'], 'elic-1');
        final resp =
            repo.respondElicitationCalls.single['resp'] as ElicitationResponse;
        expect(resp.toJson(), {
          'action': 'accept',
          'content': {'color': 'blue'},
        });
      },
    );

    testWidgets(
      'swapping to a new item (different requestId) resets form field state',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<ElicitationCubit>.value(
            value: cubit,
            child: ElicitationCard(
              item: item,
              onRespond: (_, __) {},
            ),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        await tester.enterText(find.byType(TextField), 'blue');
        await _settle(tester);
        expect(find.text('blue'), findsOneWidget);

        const nextItem = ElicitationRequestTimelineItem(
          requestId: 'elic-2',
          message: 'Pick another value',
          mode: 'form',
          order: OrderKey(2),
          schema: {
            'type': 'object',
            'properties': {
              'color': {'type': 'string', 'title': 'Color'},
            },
          },
        );
        await tester.pumpWidget(_wrap(
          BlocProvider<ElicitationCubit>.value(
            value: cubit,
            child: ElicitationCard(
              item: nextItem,
              onRespond: (_, __) {},
            ),
          ),
        ));
        await _settle(tester);

        expect(find.text('Pick another value'), findsOneWidget);
        expect(find.text('blue'), findsNothing);
      },
    );
  });
}
