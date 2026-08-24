import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'adapters/notification_settings_adapter.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<NotificationRuleCubit>()..watchRules(),
        child: NotificationSettingsAdapter(
          onEnableDevice: getIt<PushService>().requestPermissions,
        ),
      );
}

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onEnableDevice,
  });

  static const List<(String, String)> types = [
    ('chat_reply', 'chatReply'),
    ('schedule', 'schedule'),
    ('task_complete', 'taskComplete'),
    ('task_error', 'taskError'),
  ];

  final NotificationRuleState state;
  final Future<void> Function(String type, bool enabled) onChanged;
  final Future<bool> Function() onEnableDevice;

  String _labelFor(BuildContext context, String key) => switch (key) {
        'chatReply' => context.l10n.notificationSettingsChatReplyLabel,
        'schedule' => context.l10n.notificationSettingsScheduleLabel,
        'taskComplete' => context.l10n.notificationSettingsTaskCompleteLabel,
        'taskError' => context.l10n.notificationSettingsTaskErrorLabel,
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.notificationSettingsScreenTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.notificationSettingsScreenTitle,
        child: switch (state.status) {
          UiFlowStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          UiFlowStatus.failure => Center(
              child: Text(
                'ERROR: ${state.error}',
                style: TextStyle(color: context.terminalColors.warning),
              ),
            ),
          UiFlowStatus.success => ListView(
              children: [
                PocoBubble(
                  message: context.l10n.notificationSettingsPoco,
                  pocoSize: AppSizes.fontLarge,
                ),
                VSpace.x3,
                TerminalButton(
                  label: context.l10n.notificationSettingsEnableDevice,
                  onTap: onEnableDevice,
                ),
                VSpace.x3,
                BiosSection(
                  title: context.l10n.notificationSettingsScreenTitle,
                  child: Column(
                    children: [
                      for (final (type, key) in types)
                        _SwitchTile(
                          label: _labelFor(context, key),
                          value: state.rules[type] ?? true,
                          onChanged: (value) => onChanged(type, value),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          UiFlowStatus.idle => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space,
          vertical: AppSizes.space / 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: context.colorScheme.onSurface,
                  fontSize: AppSizes.fontStandard,
                  fontWeight: AppFonts.heavy,
                  package: 'pocketcoder_flutter',
                ),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}
