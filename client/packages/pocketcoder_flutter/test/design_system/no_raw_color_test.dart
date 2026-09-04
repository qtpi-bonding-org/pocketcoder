// FOSS/test/design_system/no_raw_color_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Every file below still uses raw Color/AppPalette values. Tasks 7-19 migrate
/// them to role-based color one widget at a time. Remove a file from this set
/// when its migration lands — that's what makes this guard test start protecting it.
/// This list is honest: it exempts exactly what currently violates the rule,
/// and as migrations land, the test starts enforcing for each freed file.
const _colorExemptions = {
  'lib/presentation/agent/widgets/plan_panel.dart',
  'lib/presentation/boot/boot_view.dart',
  'lib/presentation/chat/adapters/chat_adapter.dart',
  'lib/presentation/chat/chat_message_bubble.dart',
  'lib/presentation/chat/pocketcoder_chat_builders.dart',
  'lib/presentation/chat/widgets/chat_view.dart',
  'lib/presentation/core/widgets/bios_action_strip.dart',
  // Reverse-video press state needs a raw ground color to swap onto; no
  // role-based background-color primitive exists yet (TextRole only
  // defines foreground colors). DetailRow is BiosRow's structural
  // replacement (task 9) and inherits the same underlying gap.
  'lib/presentation/core/widgets/detail_row.dart',
  // The border is spec-mandated to be exactly AppPalette.dim (task 13's
  // own decision_frame_test.dart asserts this directly); no role-based
  // border-color primitive exists yet, same underlying gap as above.
  'lib/presentation/core/widgets/decision_frame.dart',
  'lib/presentation/core/widgets/release_status_banner.dart',
  'lib/presentation/core/widgets/terminal_button.dart',
  'lib/presentation/core/widgets/terminal_confirm_dialog.dart',
  'lib/presentation/core/widgets/terminal_conversation.dart',
  'lib/presentation/core/widgets/terminal_dialog.dart',
  'lib/presentation/core/widgets/terminal_text_field.dart',
  'lib/presentation/core/widgets/vim_toast.dart',
  'lib/presentation/onboarding/adapters/self_host_login_adapter.dart',
  'lib/presentation/onboarding/adapters/self_host_setup_adapter.dart',
  'lib/presentation/settings/adapters/settings_adapter.dart',
};

void main() {
  test('no raw Color/AppPalette outside design system', () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_colorExemptions.any(f.path.endsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('Color(0x') ||
            line.contains('Colors.') ||
            line.contains('AppPalette.')) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
Color roles enable @media-style theme switching and semantic consistency.
Widgets take roles (TextRole, ButtonRole, etc.), not raw values. Raw Color
literals and AppPalette constants will migrate across Tasks 7-19 as each
widget adopts role-based theming. See the call-site inventory in this
plan's Task 6 brief for which task owns each widget.

New violations detected (should be empty):
${offenders.join('\n')}
''');
  });
}
