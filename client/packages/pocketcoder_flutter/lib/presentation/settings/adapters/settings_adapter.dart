import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/settings_view.dart';

final Uri _reportAiContentUri = Uri(
  scheme: 'mailto',
  path: 'marketing@qtpi.app',
  query: 'subject=PocketCoder AI content report',
);

bool _hasPendingMcp(McpState state) =>
    state.status == UiFlowStatus.success &&
    state.servers.any((server) => server.status == McpServerStatus.pending);

class SettingsAdapter extends CubitAdapter<AuthCubit, AuthState> {
  const SettingsAdapter({super.key});

  static AuthState _selectState(AuthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<AuthCubit, AuthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final authCubit = context.read<AuthCubit>();
    final mcpCubit = context.read<McpCubit>();
    final localSettings = GetIt.instance<ILocalSettingsService>();
    return UiFlowListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isSuccess &&
            !state.skipOnboardingNavigation &&
            context.mounted) {
          context.goNamed(RouteNames.onboarding);
        }
      },
      child: ValueListenableBuilder<AuthState>(
        valueListenable: state,
        builder: (context, _, __) => StreamBuilder<McpState>(
          initialData: mcpCubit.state,
          stream: mcpCubit.stream,
          builder: (context, mcpSnapshot) => StreamBuilder<bool>(
            initialData: localSettings.hapticsEnabledSync,
            stream: localSettings.watchHapticsEnabled(),
            builder: (context, hapticsSnapshot) => SettingsView(
              hasPendingMcp: _hasPendingMcp(mcpSnapshot.data ?? mcpCubit.state),
              isPro: GetIt.instance<IAppEdition>().isPro,
              hapticsEnabled:
                  hapticsSnapshot.data ?? localSettings.hapticsEnabledSync,
              onNavigate: (routeKey) => _navigateTo(context, routeKey),
              onLogout: () => _confirmLogout(context, authCubit),
              onFactoryReset: () => _confirmFactoryReset(context, authCubit),
              onDeleteProData: () => _confirmDeleteProData(context, authCubit),
              onReportAiContent: () => launchUrl(_reportAiContentUri),
              onHapticsChanged: localSettings.setHapticsEnabled,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthCubit cubit) {
    showDialog<void>(
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
            style: TextButton.styleFrom(
              foregroundColor: context.terminalColors.warning,
            ),
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

  void _confirmFactoryReset(BuildContext context, AuthCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsFactoryResetConfirmTitle,
        content: Text(context.l10n.settingsFactoryResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.settingsFactoryResetCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.terminalColors.danger,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.factoryReset();
            },
            child: Text(context.l10n.settingsFactoryResetConfirm),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProData(BuildContext context, AuthCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsDeleteProDataConfirmTitle,
        content: Text(context.l10n.settingsDeleteProDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.settingsDeleteProDataCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.terminalColors.danger,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.deleteProData();
            },
            child: Text(context.l10n.settingsDeleteProDataConfirm),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeKey) {
    final route = switch (routeKey) {
      'configureAi' => AppRoutes.configureAi,
      'configureToolPermissions' => AppRoutes.configureToolPermissions,
      'configureMcp' => AppRoutes.configureMcp,
      'configureSkills' => AppRoutes.configureSkills,
      'configureSystemChecks' => AppRoutes.configureSystemChecks,
      'configurePaywall' => AppRoutes.configurePaywall,
      'configureMemory' => AppRoutes.configureMemory,
      'configurePocketbase' => AppRoutes.configurePocketbase,
      'configureLlm' => AppRoutes.configureLlm,
      'configureHarnessAuth' => AppRoutes.configureHarnessAuth,
      'configureScheduler' => AppRoutes.configureScheduler,
      'configureNotifications' => AppRoutes.configureNotifications,
      'configureErrors' => AppRoutes.configureErrors,
      _ => null,
    };
    if (route != null) context.push(route);
  }
}
