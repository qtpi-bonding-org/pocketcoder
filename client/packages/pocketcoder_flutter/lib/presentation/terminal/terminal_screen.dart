import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';
import '../../app/bootstrap.dart';
import '../../application/terminal/terminal_cubit.dart';
import '../../application/terminal/terminal_state.dart';
import '../../application/chat/communication_cubit.dart';
import '../../application/system/status_cubit.dart';
import '../../application/system/status_state.dart';
import '../../app_router.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/terminal_button.dart';
import '../core/widgets/ui_flow_listener.dart';

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
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                VSpace.x3,
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
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
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
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: Column(
              children: [
                PocoAnimator(fontSize: AppSizes.fontBig),
                VSpace.x0_5,
                Text(
                  'Terminal Mirror',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.8),
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontTiny,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        VSpace.x2,
        BlocBuilder<StatusCubit, StatusState>(builder: (context, state) {
          final isConnected = state.isConnected;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SSH SESSION: sandbox:2222',
                style: context.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '[ ${isConnected ? 'ONLINE' : 'OFFLINE'} ]',
                style: TextStyle(
                  color: isConnected
                      ? context.terminalColors.warning
                      : context.terminalColors.danger,
                  fontSize: AppSizes.fontMini,
                  letterSpacing: 1,
                ),
              ),
            ],
          );
        }),
        VSpace.x1,
        Container(
          height: 1,
          width: double.infinity,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
