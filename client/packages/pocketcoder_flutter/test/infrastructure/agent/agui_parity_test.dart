// Down-channel parity golden test (plan Task 7): every line of
// test/fixtures/agui_frames.jsonl is a real `data:` JSON payload captured
// from a live c1 (PocketBase) SSE stream against pinned Goose + MiniMax-M2.5
// (see plan Task 4's "capture the golden corpus" step). This is the
// Go-emit <-> Dart-decode drift gate: if the pinned `ag_ui` package or c1's
// event shapes ever diverge, this test is the first thing to fail.
import 'dart:convert';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agui_decode.dart';

// Resolves regardless of invocation style: `flutter test` run from within
// this package (CWD = package root, relative path works directly) or run
// as `flutter test packages/pocketcoder_flutter` from the client/ workspace
// root (tests/run-integration-suite.sh's own invocation) -- CWD stays at
// client/ in that mode, so the bare relative path silently resolves to a
// nonexistent file instead of the real fixture.
File _resolveFixtureFile() {
  const relative = 'test/fixtures/agui_frames.jsonl';
  final direct = File(relative);
  if (direct.existsSync()) return direct;
  return File('packages/pocketcoder_flutter/$relative');
}

void main() {
  final fixtureFile = _resolveFixtureFile();

  test('fixture file exists and is non-empty', () {
    expect(fixtureFile.existsSync(), isTrue,
        reason: 'expected ${fixtureFile.path} — run the capture step from '
            'plan Task 4 if this is missing');
    expect(fixtureFile.readAsLinesSync(), isNotEmpty);
  });

  final lines = fixtureFile.existsSync()
      ? fixtureFile
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList()
      : <String>[];

  test('every captured frame decodes without throwing', () {
    for (final line in lines) {
      expect(
        () => decodeAguiFrame(line),
        returnsNormally,
        reason: 'failed to decode: $line',
      );
    }
  });

  test(
      'every captured frame yields the AG-UI event subtype its own '
      '"type" field names', () {
    // This is the real parity assertion: decode each frame and confirm the
    // concrete Dart type ag_ui produced actually corresponds to the wire
    // "type" discriminator, rather than e.g. silently falling back to a
    // generic/raw event for a shape ag_ui doesn't recognise.
    const expectedRuntimeType = {
      'RUN_STARTED': RunStartedEvent,
      'RUN_FINISHED': RunFinishedEvent,
      'RUN_ERROR': RunErrorEvent,
      'TEXT_MESSAGE_START': TextMessageStartEvent,
      'TEXT_MESSAGE_CONTENT': TextMessageContentEvent,
      'TEXT_MESSAGE_END': TextMessageEndEvent,
      'REASONING_MESSAGE_START': ReasoningMessageStartEvent,
      'REASONING_MESSAGE_CONTENT': ReasoningMessageContentEvent,
      'REASONING_MESSAGE_END': ReasoningMessageEndEvent,
      'TOOL_CALL_START': ToolCallStartEvent,
      'TOOL_CALL_ARGS': ToolCallArgsEvent,
      'TOOL_CALL_RESULT': ToolCallResultEvent,
      'TOOL_CALL_END': ToolCallEndEvent,
      'STATE_SNAPSHOT': StateSnapshotEvent,
      'STATE_DELTA': StateDeltaEvent,
      'CUSTOM': CustomEvent,
    };

    for (final line in lines) {
      final wireType =
          (jsonDecode(line) as Map<String, dynamic>)['type'] as String;
      final decoded = decodeAguiFrame(line);
      final expected = expectedRuntimeType[wireType];
      expect(
        expected,
        isNotNull,
        reason: 'fixture line has an unhandled wire type: $wireType. Add it '
            'to expectedRuntimeType above (or drop the fixture line if it is '
            'not one of the event kinds the reducer needs).',
      );
      expect(
        decoded.event.runtimeType,
        expected,
        reason: 'wire type $wireType decoded to '
            '${decoded.event.runtimeType}, want $expected',
      );
      expect(decoded.rawJson, line,
          reason: 'DecodedFrame.rawJson must be the verbatim input, not a '
              're-encode, so the cache never lossily round-trips it');
    }
  });

  test('the fixture corpus includes the pocketcoder:sync replace marker', () {
    final hasReplaceMarker =
        lines.map(decodeAguiFrame).any((frame) => isReplaceMarker(frame.event));
    expect(hasReplaceMarker, isTrue,
        reason: 'fixture must include at least one cold-replay replace '
            'marker (plan Task 2) so isReplaceMarker has real coverage');
  });

  test('isReplaceMarker is false for an ordinary CUSTOM event', () {
    final ordinaryCustom = lines.map(decodeAguiFrame).firstWhere(
        (frame) => frame.event is CustomEvent && !isReplaceMarker(frame.event));
    expect(isReplaceMarker(ordinaryCustom.event), isFalse);
  });
}
