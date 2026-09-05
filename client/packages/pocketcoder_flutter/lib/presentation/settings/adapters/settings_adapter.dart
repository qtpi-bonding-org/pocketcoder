import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
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
        title: context.l10n.settingsLogoutConfirmTitle.toLowerCase(),
        content: Text(context.l10n.settingsLogoutConfirmBody),
        actions: [
          TerminalButton(
            label: context.l10n.settingsLogoutCancel,
            kind: ActionKind.refusal,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          TerminalButton(
            label: context.l10n.settingsLogoutConfirm,
            kind: ActionKind.primary,
            onTap: () {
              Navigator.of(dialogContext).pop();
              cubit.logout();
            },
          ),
        ],
      ),
    );
  }

  void _confirmFactoryReset(BuildContext context, AuthCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsFactoryResetConfirmTitle.toLowerCase(),
        content: Text(context.l10n.settingsFactoryResetConfirmBody),
        actions: [
          TerminalButton(
            label: context.l10n.settingsFactoryResetCancel,
            kind: ActionKind.refusal,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          TerminalButton(
            label: context.l10n.settingsFactoryResetConfirm,
            kind: ActionKind.destructive,
            onTap: () {
              Navigator.of(dialogContext).pop();
              cubit.factoryReset();
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProData(BuildContext context, AuthCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsDeleteProDataConfirmTitle.toLowerCase(),
        content: Text(context.l10n.settingsDeleteProDataConfirmBody),
        actions: [
          TerminalButton(
            label: context.l10n.settingsDeleteProDataCancel,
            kind: ActionKind.refusal,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          TerminalButton(
            label: context.l10n.settingsDeleteProDataConfirm,
            kind: ActionKind.destructive,
            onTap: () {
              Navigator.of(dialogContext).pop();
              cubit.deleteProData();
            },
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
      'statusSystemChecks' => AppRoutes.statusSystemChecks,
      'configurePaywall' => AppRoutes.configurePaywall,
      'statusMemory' => AppRoutes.statusMemory,
      'statusPocketbase' => AppRoutes.statusPocketbase,
      'configureLlm' => AppRoutes.configureLlm,
      'configureHarnessAuth' => AppRoutes.configureHarnessAuth,
      'configureScheduler' => AppRoutes.configureScheduler,
      'configureNotifications' => AppRoutes.configureNotifications,
      'statusErrors' => AppRoutes.statusErrors,
      _ => null,
    };
    if (route != null) context.push(route);
  }
}
