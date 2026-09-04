// FOSS/test/design_system/no_raw_color_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Every file below still uses raw Color/AppPalette values. Tasks 7-19 migrate
/// them to role-based color one widget at a time. Remove a file from this set
/// when its migration lands — that's what makes this guard test start protecting it.
/// This list is honest: it exempts exactly what currently violates the rule,
/// and as migrations land, the test starts enforcing for each freed file.
const _colorExemptions = {
  'lib/presentation/agent_config/widgets/agent_config_view.dart',
  'lib/presentation/agent/widgets/plan_panel.dart',
  'lib/presentation/billing/widgets/unavailable_pro_offer.dart',
  'lib/presentation/boot/boot_view.dart',
  'lib/presentation/chat/adapters/chat_adapter.dart',
  'lib/presentation/chat/chat_message_bubble.dart',
  'lib/presentation/chat/permission_card.dart',
  'lib/presentation/chat/pocketcoder_chat_builders.dart',
  'lib/presentation/chat/widgets/chat_view.dart',
  'lib/presentation/core/widgets/bios_action_strip.dart',
  'lib/presentation/core/widgets/bios_frame.dart',
  'lib/presentation/core/widgets/bios_row.dart',
  'lib/presentation/core/widgets/release_status_banner.dart',
  'lib/presentation/core/widgets/terminal_button.dart',
  'lib/presentation/core/widgets/terminal_confirm_dialog.dart',
  'lib/presentation/core/widgets/terminal_conversation.dart',
  'lib/presentation/core/widgets/terminal_dialog_actions.dart',
  'lib/presentation/core/widgets/terminal_dialog.dart',
  'lib/presentation/core/widgets/terminal_status_glyph.dart',
  'lib/presentation/core/widgets/terminal_text_field.dart',
  'lib/presentation/core/widgets/vim_toast.dart',
  'lib/presentation/errors/error_inbox_screen.dart',
  'lib/presentation/errors/widgets/error_tile.dart',
  'lib/presentation/foss/foss_server_setup_view.dart',
  'lib/presentation/harness_auth/widgets/harness_auth_status_block.dart',
  'lib/presentation/harness_auth/widgets/harness_auth_view.dart',
  'lib/presentation/mcp/widgets/mcp_management_view.dart',
  'lib/presentation/monitor/widgets/monitor_registry_and_logs.dart',
  'lib/presentation/notifications/notification_settings_screen.dart',
  'lib/presentation/observability/memory_dashboard_screen.dart',
  'lib/presentation/onboarding/adapters/self_host_login_adapter.dart',
  'lib/presentation/onboarding/adapters/self_host_setup_adapter.dart',
  'lib/presentation/onboarding/widgets/agent_auth_view.dart',
  'lib/presentation/pocketbase_inspector/pocketbase_inspector_screen.dart',
  'lib/presentation/provider/adapters/provider_adapter.dart',
  'lib/presentation/scheduler/widgets/scheduler_view.dart',
  'lib/presentation/server_control/server_control_view.dart',
  'lib/presentation/settings/adapters/settings_adapter.dart',
  'lib/presentation/skills/widgets/skill_card.dart',
  'lib/presentation/skills/widgets/skills_view.dart',
  'lib/presentation/tool_permissions/widgets/tool_permissions_view.dart',
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
