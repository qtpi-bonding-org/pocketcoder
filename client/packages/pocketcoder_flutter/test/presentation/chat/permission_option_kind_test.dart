import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_command.dart';

void main() {
  test('reject-kind options are refusals', () {
    expect(actionKindForPermissionOption('reject_once'), ActionKind.refusal);
    expect(actionKindForPermissionOption('reject_always'), ActionKind.refusal);
  });

  test('allow-kind options are primary', () {
    expect(actionKindForPermissionOption('allow_once'), ActionKind.primary);
    expect(actionKindForPermissionOption('allow_always'), ActionKind.primary);
  });

  test('no harness-supplied kind can ever be destructive', () {
    // Deciding an agent's command is destructive requires interpreting
    // arbitrary input, which the honesty principle forbids: a confidently
    // wrong "this will delete your data" manufactures consent.
    const adversarial = [
      'destructive',
      'delete',
      'rm -rf /',
      'DESTRUCTIVE',
      'wipe',
      'reject_destructive',
      '',
      '   ',
      'allow_delete_everything',
    ];
    for (final k in adversarial) {
      expect(actionKindForPermissionOption(k), isNot(ActionKind.destructive),
          reason: 'harness kind "$k" must not map to destructive');
    }
  });
}
