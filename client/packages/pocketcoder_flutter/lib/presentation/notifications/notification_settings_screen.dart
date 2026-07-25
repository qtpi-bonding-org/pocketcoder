import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

/// User-facing toggles for which notification types the agent is allowed
/// to push to this device.
///
/// The four types are static (not user-creatable) because the schema is
/// a per-user map of `{type: bool}`. New notification types are added
/// here when the backend gains a caller for them.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const List<(String, String)> _types = [
    ('chat_reply', 'chatReply'),
    ('schedule', 'schedule'),
    ('task_complete', 'taskComplete'),
    ('task_error', 'taskError'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationRuleCubit>(
      create: (_) => getIt<NotificationRuleCubit>()..watchRules(),
      child: UiFlowListener<NotificationRuleCubit, NotificationRuleState>(
        child: const _NotificationSettingsView(),
      ),
    );
  }
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  String _labelFor(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'chatReply':
        return l10n.notificationSettingsChatReplyLabel;
      case 'schedule':
        return l10n.notificationSettingsScheduleLabel;
      case 'taskComplete':
        return l10n.notificationSettingsTaskCompleteLabel;
      case 'taskError':
        return l10n.notificationSettingsTaskErrorLabel;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.notificationSettingsScreenTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.notificationSettingsScreenTitle,
        child: BlocBuilder<NotificationRuleCubit, NotificationRuleState>(
          buildWhen: (previous, current) => previous != current,
          builder: (context, state) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (rules) {
                return ListView(
                  children: [
                    BiosSection(
                      title: context.l10n.notificationSettingsScreenTitle,
                      child: Column(
                        children: [
                          for (final (type, key) in NotificationSettingsScreen._types)
                            _buildSwitchTile(
                              context,
                              type: type,
                              label: _labelFor(context, key),
                              value: rules[type] ?? true,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (msg) => Center(
                child: Text(
                  'ERROR: $msg',
                  style: TextStyle(color: colors.error),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String type,
    required String label,
    required bool value,
  }) {
    return Padding(
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
          Switch(
            value: value,
            onChanged: (next) =>
                context.read<NotificationRuleCubit>().setTypeEnabled(type, next),
          ),
        ],
      ),
    );
  }
}
