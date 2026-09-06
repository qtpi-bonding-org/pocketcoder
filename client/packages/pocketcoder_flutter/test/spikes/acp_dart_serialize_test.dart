// Spike (plan Task 5, spec §13 Q1): confirm acp_dart's up-channel request
// types serialize standalone via toJson() without instantiating any
// ClientSideConnection/transport. If any type below is not standalone
// serializable, record the deviation in the design spec's §13 Q1 and adjust
// Task 9 accordingly.
import 'package:acp_dart/acp_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PromptRequest.toJson() is standalone-serializable', () {
    final req = PromptRequest(
      sessionId: 'session-1',
      prompt: [TextContentBlock(text: 'hello')],
    );
    final json = req.toJson();
    expect(json['sessionId'], 'session-1');
    expect(json['prompt'], isA<List>());
    expect((json['prompt'] as List).first['type'], 'text');
    expect((json['prompt'] as List).first['text'], 'hello');
  });

  test(
      'RequestPermissionResponse.toJson() is standalone-serializable '
      '(selected + cancelled outcomes)', () {
    final selected = RequestPermissionResponse(
      outcome: SelectedOutcome(optionId: 'allow_once'),
    );
    final selectedJson = selected.toJson();
    expect(selectedJson['outcome']['outcome'], 'selected');
    expect(selectedJson['outcome']['optionId'], 'allow_once');

    final cancelled = RequestPermissionResponse(outcome: CancelledOutcome());
    final cancelledJson = cancelled.toJson();
    expect(cancelledJson['outcome']['outcome'], 'cancelled');
  });

  test('SetSessionModeRequest.toJson() is standalone-serializable', () {
    final req = SetSessionModeRequest(sessionId: 'session-1', modeId: 'chat');
    final json = req.toJson();
    expect(json['sessionId'], 'session-1');
    expect(json['modeId'], 'chat');
  });

  test('SetSessionConfigOptionRequest.toJson() is standalone-serializable', () {
    final req = SetSessionConfigOptionRequest(
      sessionId: 'session-1',
      configId: 'mode',
      value: 'approve',
    );
    final json = req.toJson();
    expect(json['sessionId'], 'session-1');
    expect(json['configId'], 'mode');
    expect(json['value'], 'approve');
  });
}
