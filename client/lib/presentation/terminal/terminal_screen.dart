import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';
import 'package:test_app/app/bootstrap.dart';
import 'package:test_app/application/terminal/terminal_cubit.dart';
import 'package:test_app/application/terminal/terminal_state.dart';
import 'package:test_app/application/chat/communication_cubit.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/terminal_footer.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../../design_system/theme/app_theme.dart';
import 'package:test_app/application/system/status_cubit.dart';
import 'package:test_app/application/system/status_state.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SshTerminalCubit>(),
      child: const _TerminalView(),
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
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                VSpace.x3,
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppPalette.primary.textPrimary
                            .withValues(alpha: 0.2),
                      ),
                      color: AppPalette.primary.backgroundPrimary
                          .withValues(alpha: 0.3),
                    ),
                    child: BlocBuilder<SshTerminalCubit, SshTerminalState>(
                      builder: (context, state) {
                        final cubit = context.read<SshTerminalCubit>();

                        if (state.isConnecting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (state.error != null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('CONNECTION FAILED',
                                    style: TextStyle(
                                        color: AppPalette.primary.errorColor)),
                                VSpace.x1,
                                Text(state.error!,
                                    style: TextStyle(
                                        color: AppPalette.primary.textPrimary,
                                        fontSize: AppSizes.fontTiny)),
                                VSpace.x2,
                                ElevatedButton(
                                    onPressed: _connect,
                                    child: const Text('RETRY')),
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
            keyLabel: 'F1',
            label: 'BACK TO CHAT',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            keyLabel: 'F5',
            label: 'RECONNECT',
            onTap: _connect,
          ),
          TerminalAction(
            keyLabel: 'ESC',
            label: 'LOGOUT',
            onTap: () => context.goNamed(RouteNames.boot),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                    color:
                        AppPalette.primary.textPrimary.withValues(alpha: 0.8),
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
                  color: AppPalette.primary.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '[ ${isConnected ? 'ONLINE' : 'OFFLINE'} ]',
                style: TextStyle(
                  color: isConnected
                      ? AppPalette.primary.textPrimary
                      : AppPalette.primary.errorColor,
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
          color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
