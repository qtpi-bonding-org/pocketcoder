// Pure, highest-value tests for ConversationReducer (plan Task 10) — one
// behavior each, per the plan's checklist.
import 'package:ag_ui/ag_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation_reducer.dart';

BaseEvent _sync() =>
    CustomEvent(name: 'pocketcoder:sync', value: {'mode': 'replace'});

StateDeltaEvent _delta(String path, {String op = 'add', dynamic value}) {
  return StateDeltaEvent(delta: [
    {'op': op, 'path': path, if (value != null) 'value': value},
  ]);
}

void main() {
  group('text messages', () {
    test('START/CONTENT x2/END -> one assistant message with concatenated text',
        () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
        const TextMessageContentEvent(messageId: 'm1', delta: 'world!'),
        const TextMessageEndEvent(messageId: 'm1'),
      ]);

      expect(conversation.messages, hasLength(1));
      final message = conversation.messages.single;
      expect(message.kind, ChatMessageKind.text);
      expect(message.role, 'assistant');
      expect(message.text, 'Hello, world!');
    });
  });

  group('reasoning messages', () {
    test('START/CONTENT/END -> one reasoning block', () {
      final conversation = reduce([
        const ReasoningMessageStartEvent(messageId: 'r1'),
        const ReasoningMessageContentEvent(messageId: 'r1', delta: 'thinking...'),
        const ReasoningMessageEndEvent(messageId: 'r1'),
      ]);

      expect(conversation.messages, hasLength(1));
      final message = conversation.messages.single;
      expect(message.kind, ChatMessageKind.reasoning);
      expect(message.text, 'thinking...');
    });
  });

  group('tool calls', () {
    test('START/ARGS/RESULT/END -> one tool-call with name, args, result', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '{"cmd":'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '"ls"}'),
        const ToolCallResultEvent(
            messageId: 'tool-result-t1', toolCallId: 't1', content: 'file1\nfile2'),
        const ToolCallEndEvent(toolCallId: 't1'),
      ]);

      expect(conversation.toolCalls, hasLength(1));
      final toolCall = conversation.toolCalls.single;
      expect(toolCall.name, 'shell');
      expect(toolCall.args, '{"cmd":"ls"}');
      expect(toolCall.result, 'file1\nfile2');
    });
  });

  group('permission state', () {
    test('STATE_DELTA add /pocketcoder/permission then remove -> present then cleared',
        () {
      final afterAdd = reduce([
        _delta('/pocketcoder/permission', value: {'status': 'pending', 'requestId': 'req-1'}),
      ]);
      expect(afterAdd.sessionState.permission, isNotNull);
      expect(afterAdd.sessionState.permission?['requestId'], 'req-1');

      final afterRemove = reduce([
        _delta('/pocketcoder/permission', value: {'status': 'pending', 'requestId': 'req-1'}),
        _delta('/pocketcoder/permission', op: 'remove'),
      ]);
      expect(afterRemove.sessionState.permission, isNull);
    });
  });

  group('elicitation state', () {
    test('STATE_DELTA add /pocketcoder/elicitation -> form surfaced with requestedSchema',
        () {
      final conversation = reduce([
        _delta('/pocketcoder/elicitation', value: {
          'elicitationId': 'e1',
          'message': 'Please confirm',
          'requestedSchema': {'type': 'object'},
        }),
      ]);

      final elicitation = conversation.sessionState.elicitation;
      expect(elicitation, isNotNull);
      expect(elicitation?['elicitationId'], 'e1');
      expect(elicitation?['requestedSchema'], {'type': 'object'});
    });
  });

  group('config state', () {
    test('STATE_DELTA /pocketcoder/config -> config options surfaced', () {
      final viaDelta = reduce([
        _delta('/pocketcoder/config', value: {
          'options': [
            {'kind': 'boolean', 'id': 'x', 'name': 'X', 'currentValue': true},
          ],
        }),
      ]);
      expect(viaDelta.sessionState.config?['options'], hasLength(1));
    });

    test('STATE_SNAPSHOT /pocketcoder/config -> config options surfaced', () {
      final viaSnapshot = reduce([
        StateSnapshotEvent(snapshot: {
          'pocketcoder': {
            'config': {
              'options': [
                {'kind': 'select', 'id': 'mode', 'name': 'Mode', 'currentValue': 'auto'},
              ],
            },
          },
        }),
      ]);
      expect(viaSnapshot.sessionState.config?['options'], hasLength(1));
    });
  });

  group('modes state (guards Task 3)', () {
    test('snapshot + CurrentModeUpdate-style sub-path delta -> currentModeId '
        'updated, availableModes retained', () {
      final conversation = reduce([
        StateSnapshotEvent(snapshot: {
          'pocketcoder': {
            'modes': {
              'currentModeId': 'auto',
              'availableModes': [
                {'id': 'auto', 'name': 'auto'},
                {'id': 'chat', 'name': 'chat'},
              ],
            },
          },
        }),
        _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
      ]);

      final modes = conversation.sessionState.modes;
      expect(modes?['currentModeId'], 'chat');
      expect(modes?['availableModes'], hasLength(2));
    });

    test('sub-path patch applied when parent absent -> parent created, no throw',
        () {
      expect(
        () => reduce([
          _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
        ]),
        returnsNormally,
      );
      final conversation = reduce([
        _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
      ]);
      expect(conversation.sessionState.modes?['currentModeId'], 'chat');
    });
  });

  group('session_info state', () {
    test('STATE_DELTA session_info -> title surfaced', () {
      final conversation = reduce([
        _delta('/pocketcoder/session_info', value: {'title': 'Fix the bug'}),
      ]);
      expect(conversation.sessionState.title, 'Fix the bug');
    });
  });

  group('replace marker', () {
    test('a pocketcoder:sync CUSTOM event resets the accumulator', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'stale', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'stale', delta: 'this should be discarded'),
        const TextMessageEndEvent(messageId: 'stale'),
        _delta('/pocketcoder/permission', value: {'status': 'pending'}),
        _sync(),
        const TextMessageStartEvent(messageId: 'fresh', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'fresh', delta: 'kept'),
        const TextMessageEndEvent(messageId: 'fresh'),
      ]);

      expect(conversation.messages, hasLength(1));
      expect(conversation.messages.single.text, 'kept');
      expect(conversation.sessionState.permission, isNull);
    });
  });
}
