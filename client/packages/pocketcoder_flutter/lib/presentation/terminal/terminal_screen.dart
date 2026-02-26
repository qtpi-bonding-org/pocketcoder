import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_cubit.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_state.dart';
import 'package:pocketcoder_flutter/application/chat/communication_cubit.dart';
import 'package:pocketcoder_flutter/application/system/status_cubit.dart';
import 'package:pocketcoder_flutter/application/system/status_state.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SshTerminalCubit>(),
      child: UiFlowListener<SshTerminalCubit, SshTerminalState>(
        autoDismissLoading: false, // We show custom loading UI
        child: const _TerminalView(),
      ),
    );
  }
}

class _TerminalView extends StatefulWidget {
  const _TerminalView();

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  void _connect() {
    final chatState = context.read<CommunicationCubit>().state;
    final opencodeId = chatState.opencodeId;

    context.read<SshTerminalCubit>().connect(
          host: 'localhost', // Sandbox is exposed on localhost for the client
          port: 2222,
          username: 'worker',
          sessionId: opencodeId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return TerminalScaffold(
      title: 'TERMINAL MIRROR',
      actions: [
        TerminalAction(
          label: 'BACK TO CHAT',
          onTap: () => context.goNamed(RouteNames.home),
        ),
        TerminalAction(
          label: 'RECONNECT',
          onTap: _connect,
        ),
        TerminalAction(
          label: 'LOGOUT',
          onTap: () => context.goNamed(RouteNames.boot),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatus(context),
          VSpace.x2,
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                color: colors.surface.withValues(alpha: 0.3),
              ),
              child: BlocBuilder<SshTerminalCubit, SshTerminalState>(
                builder: (context, state) {
                  final cubit = context.read<SshTerminalCubit>();

                  if (state.isConnecting) {
                    return const Center(
                      child: TerminalLoadingIndicator(
                        label: 'ESTABLISHING SSH LINK',
                      ),
                    );
                  }

                  if (state.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CONNECTION FAILED',
                            style: TextStyle(
                              color: colors.error,
                              fontFamily: AppFonts.bodyFamily,
                              fontWeight: AppFonts.heavy,
                            ),
                          ),
                          VSpace.x1,
                          Text(
                            state.error!.toString().toUpperCase(),
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: AppSizes.fontTiny,
                              fontFamily: AppFonts.bodyFamily,
                            ),
                          ),
                          VSpace.x4,
                          TerminalButton(
                              label: 'RETRY CONNECTION', onTap: _connect),
                        ],
                      ),
                    );
                  }

                  return TerminalView(
                    cubit.terminal,
                    autofocus: true,
                  );
                },
              ),
            ),
          ),
          VSpace.x1_5,
        ],
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    return BlocBuilder<StatusCubit, StatusState>(builder: (context, state) {
      final colors = context.colorScheme;
      final isConnected = state.isConnected;
      return BiosSection(
        title: 'CONNECTION_STATUS',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SSH LINK: SANDBOX:2222',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontSize: AppSizes.fontMini,
                package: 'pocketcoder_flutter',
              ),
            ),
            Text(
              '[ ${isConnected ? 'ONLINE' : 'OFFLINE'} ]',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: isConnected
                    ? context.terminalColors.warning
                    : context.terminalColors.danger,
                fontSize: AppSizes.fontMini,
                fontWeight: AppFonts.heavy,
                package: 'pocketcoder_flutter',
              ),
            ),
          ],
        ),
      );
    });
  }
}
