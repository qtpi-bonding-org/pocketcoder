import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import '../../app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static List<(String, List<(String, String, String)>)> _sections(
      BuildContext context) {
    return [
      (context.l10n.settingsAiAgentsSection, [
        ('LLM MANAGEMENT', '[KEYS]', 'configureLlm'),
        ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
      ]),
      (context.l10n.settingsSecuritySection, [
        ('TOOL PERMISSIONS', '[SETUP]', 'configureToolPermissions'),
        ('MCP MANAGEMENT', '[CONFIGURE]', 'configureMcp'),
        ('SKILLS', '[MANAGE]', 'configureSkills'),
      ]),
      (context.l10n.settingsSystemSection, [
        ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
        ('PERMISSION RELAY', '[STATUS]', 'configurePaywall'),
        ('SERVER UPDATE', '[UPDATE]', 'updateServer'),
        (context.l10n.errorsTitle, '[VIEW]', 'configureErrors'),
      ]),
      (context.l10n.settingsObservabilitySection, [
        ('AGENT OBSERVABILITY', '[MANAGE]', 'configureObservability'),
      ]),
      (context.l10n.settingsAutomationSection, [
        ('SCHEDULER', '[MANAGE]', 'configureScheduler'),
      ]),
      (context.l10n.settingsAccountSection, [
        ('NOTIFICATIONS', '[CONFIGURE]', 'configureNotifications'),
        ('LOGOUT', '[SIGN OUT]', 'logout'),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: UiFlowListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isSuccess && context.mounted) {
            context.goNamed(RouteNames.onboarding);
          }
        },
        child: PocketCoderShell(
          title: context.l10n.settingsTitle,
          activePillar: NavPillar.configure,
          showBack: false,
          body: BlocBuilder<McpCubit, McpState>(
            builder: (context, state) {
              final hasPendingMcp = state.maybeWhen(
                loaded: (servers) =>
                    servers.any((s) => s.status == McpServerStatus.pending),
                orElse: () => false,
              );

              return ListView(
                children: [
                  for (final section in _sections(context)) ...[
                    BiosSection(
                      title: section.$1,
                      child: Column(
                        children: [
                          for (final item in section.$2)
                            Builder(builder: (context) {
                              final isMcp = item.$3 == 'configureMcp';
                              final isLogout = item.$3 == 'logout';
                              return BiosListTile(
                                label: item.$1,
                                value: item.$2,
                                hasBadge: isMcp && hasPendingMcp,
                                isDestructive: isLogout,
                                onTap: () {
                                  if (isLogout) {
                                    _confirmLogout(context);
                                  } else {
                                    _navigateTo(context, item.$3);
                                  }
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsLogoutConfirmTitle,
        content: Text(context.l10n.settingsLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.settingsLogoutCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.logout();
            },
            child: Text(context.l10n.settingsLogoutConfirm),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeKey) {
    switch (routeKey) {
      case 'configureAi':
        context.push(AppRoutes.configureAi);
      case 'configureToolPermissions':
        context.push(AppRoutes.configureToolPermissions);
      case 'configureMcp':
        context.push(AppRoutes.configureMcp);
      case 'configureSkills':
        context.push(AppRoutes.configureSkills);
      case 'configureSystemChecks':
        context.push(AppRoutes.configureSystemChecks);
      case 'configurePaywall':
        context.push(AppRoutes.configurePaywall);
      case 'updateServer':
        context.push(AppRoutes.updateServer);
      case 'configureObservability':
        context.push(AppRoutes.configureObservability);
      case 'configureLlm':
        context.push(AppRoutes.configureLlm);
      case 'configureScheduler':
        context.push(AppRoutes.configureScheduler);
      case 'configureNotifications':
        context.push(AppRoutes.configureNotifications);
      case 'configureErrors':
        context.push(AppRoutes.configureErrors);
    }
  }
}
