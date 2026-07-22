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
    test('START -> textStream item; CONTENT x2 -> grows in place; END -> replaced by text item',
        () {
      var conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
      ]);
      expect(conversation.timeline, hasLength(1));
      expect(conversation.timeline.single, isA<TextStreamTimelineItem>());
      expect((conversation.timeline.single as TextStreamTimelineItem).text, '');

      conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
      ]);
      expect(conversation.timeline, hasLength(1));
      expect((conversation.timeline.single as TextStreamTimelineItem).text, 'Hello, ');

      conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
        const TextMessageContentEvent(messageId: 'm1', delta: 'world!'),
        const TextMessageEndEvent(messageId: 'm1'),
      ]);
      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as TextTimelineItem;
      expect(item.kind, ChatMessageKind.text);
      expect(item.role, 'assistant');
      expect(item.text, 'Hello, world!');
    });
  });

  group('reasoning messages', () {
    test('START/CONTENT/END -> one reasoning text item (no streaming placeholder)', () {
      final conversation = reduce([
        const ReasoningMessageStartEvent(messageId: 'r1'),
        const ReasoningMessageContentEvent(messageId: 'r1', delta: 'thinking...'),
        const ReasoningMessageEndEvent(messageId: 'r1'),
      ]);

      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as TextTimelineItem;
      expect(item.kind, ChatMessageKind.reasoning);
      expect(item.text, 'thinking...');
    });
  });

  group('tool calls', () {
    test('START enters the timeline immediately (before ARGS/RESULT/END)', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
      ]);
      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as ToolCallTimelineItem;
      expect(item.name, 'shell');
      expect(item.args, '');
      expect(item.result, isNull);
    });

    test('START/ARGS/RESULT/END -> one tool-call item, updated in place', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '{"cmd":'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '"ls"}'),
        const ToolCallResultEvent(
            messageId: 'tool-result-t1', toolCallId: 't1', content: 'file1\nfile2'),
        const ToolCallEndEvent(toolCallId: 't1'),
      ]);

      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as ToolCallTimelineItem;
      expect(item.name, 'shell');
      expect(item.args, '{"cmd":"ls"}');
      expect(item.result, 'file1\nfile2');
    });
  });

  group('ordering', () {
    test('text, tool call, and more text interleave in true chronological order', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'checking...'),
        const TextMessageEndEvent(messageId: 'm1'),
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        const ToolCallEndEvent(toolCallId: 't1'),
        const TextMessageStartEvent(messageId: 'm2', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm2', delta: 'done'),
        const TextMessageEndEvent(messageId: 'm2'),
      ]);

      expect(conversation.timeline, hasLength(3));
      expect(conversation.timeline[0], isA<TextTimelineItem>());
      expect(conversation.timeline[1], isA<ToolCallTimelineItem>());
      expect(conversation.timeline[2], isA<TextTimelineItem>());
    });
  });

  group('permission timeline correlation', () {
    test('permission with toolCallId inserts right after that tool call', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        const ToolCallStartEvent(toolCallId: 't2', toolCallName: 'other'),
      ]);

      expect(conversation.timeline, hasLength(3));
      expect((conversation.timeline[0] as ToolCallTimelineItem).id, 't1');
      expect(conversation.timeline[1], isA<PermissionTimelineItem>());
      expect((conversation.timeline[1] as PermissionTimelineItem).requestId, 'req-1');
      expect((conversation.timeline[2] as ToolCallTimelineItem).id, 't2');
    });

    test('permission with unknown/absent toolCallId appends at the end', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission', value: {'requestId': 'req-1', 'status': 'pending'}),
      ]);

      expect(conversation.timeline, hasLength(2));
      expect(conversation.timeline.last, isA<PermissionTimelineItem>());
    });

    test('resolving a permission (STATE_DELTA remove) removes its timeline item', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        _delta('/pocketcoder/permission', op: 'remove'),
      ]);

      expect(conversation.timeline, hasLength(1));
      expect(conversation.timeline.whereType<PermissionTimelineItem>(), isEmpty);
      expect(conversation.sessionState.permission, isNull);
    });

    test('a later ARGS delta on the correlated tool call still hits the right slot after insertion',
        () {
      // Regression guard for the index-shift bug: inserting the permission
      // item between t1 and where t1's ARGS update would land must not
      // corrupt _toolTimelineIndex.
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '{"cmd":"ls"}'),
      ]);

      final toolItem =
          conversation.timeline.whereType<ToolCallTimelineItem>().single;
      expect(toolItem.args, '{"cmd":"ls"}');
    });
  });

  group('elicitation timeline (no correlation available)', () {
    test('STATE_DELTA add /pocketcoder/elicitation -> appended at the end', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
        const TextMessageEndEvent(messageId: 'm1'),
        _delta('/pocketcoder/elicitation', value: {
          'elicitationId': 'e1',
          'message': 'Please confirm',
          'requestedSchema': {'type': 'object'},
        }),
      ]);

      expect(conversation.timeline, hasLength(2));
      expect(conversation.timeline.last, isA<ElicitationTimelineItem>());
      expect((conversation.timeline.last as ElicitationTimelineItem).requestId, 'e1');
      expect(conversation.sessionState.elicitation?['elicitationId'], 'e1');
    });
  });

  group('permission state (sessionState back-compat)', () {
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

  group('elicitation state (sessionState back-compat)', () {
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

      expect(conversation.timeline, hasLength(1));
      expect((conversation.timeline.single as TextTimelineItem).text, 'kept');
      expect(conversation.sessionState.permission, isNull);
    });
  });
}