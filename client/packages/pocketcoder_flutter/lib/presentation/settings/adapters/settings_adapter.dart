import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import '../widgets/settings_view.dart';

bool _hasPendingMcp(McpState state) => state.maybeWhen(
      loaded: (servers) =>
          servers.any((server) => server.status == McpServerStatus.pending),
      orElse: () => false,
    );

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
    return UiFlowListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isSuccess && context.mounted) {
          context.goNamed(RouteNames.onboarding);
        }
      },
      child: ValueListenableBuilder<AuthState>(
        valueListenable: state,
        builder: (context, _, __) => StreamBuilder<McpState>(
          initialData: mcpCubit.state,
          stream: mcpCubit.stream,
          builder: (context, snapshot) => SettingsView(
            hasPendingMcp: _hasPendingMcp(snapshot.data ?? mcpCubit.state),
            onNavigate: (routeKey) => _navigateTo(context, routeKey),
            onLogout: () => _confirmLogout(context, authCubit),
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
    final route = switch (routeKey) {
      'configureAi' => AppRoutes.configureAi,
      'configureToolPermissions' => AppRoutes.configureToolPermissions,
      'configureMcp' => AppRoutes.configureMcp,
      'configureSkills' => AppRoutes.configureSkills,
      'configureSystemChecks' => AppRoutes.configureSystemChecks,
      'configurePaywall' => AppRoutes.configurePaywall,
      'updateServer' => AppRoutes.updateServer,
      'configureObservability' => AppRoutes.configureObservability,
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
