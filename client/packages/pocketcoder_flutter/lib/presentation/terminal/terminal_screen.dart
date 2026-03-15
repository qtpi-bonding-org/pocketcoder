import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_cubit.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_state.dart';
import 'package:pocketcoder_flutter/application/chat/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/system/status_cubit.dart';
import 'package:pocketcoder_flutter/application/system/status_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SshTerminalCubit>(),
      child: UiFlowListener<SshTerminalCubit, SshTerminalState>(
        autoDismissLoading: false,
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
    final chatState = context.read<ChatCubit>().state;
    final opencodeId = chatState.opencodeId;

    context.read<SshTerminalCubit>().connect(
          sessionId: opencodeId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return PocketCoderShell(
      title: context.l10n.terminalTitle,
      activePillar: NavPillar.chats,
      showBack: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inline operational buttons
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space,
              vertical: AppSizes.space * 0.5,
            ),
            child: Row(
              children: [
                TerminalButton(
                  label: context.l10n.terminalTransfer,
                  onTap: () => _pickAndUploadFile(context),
                ),
                HSpace.x2,
                TerminalButton(
                  label: context.l10n.terminalReconnect,
                  onTap: _connect,
                ),
              ],
            ),
          ),
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
                    return Center(
                      child: TerminalLoadingIndicator(
                        label: context.l10n.terminalConnecting,
                      ),
                    );
                  }

                  if (state.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TerminalText(
                            context.l10n.terminalConnectionFailed,
                            color: colors.error,
                            weight: TerminalTextWeight.heavy,
                          ),
                          VSpace.x1,
                          TerminalText.tiny(
                            (state.error ?? 'Unknown error').toString().toUpperCase(),
                          ),
                          VSpace.x4,
                          TerminalButton(
                              label: context.l10n.terminalRetry, onTap: _connect),
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

  Future<void> _pickAndUploadFile(BuildContext context) async {
    final cubit = context.read<SshTerminalCubit>();
    if (!cubit.state.isConnected || cubit.state.isUploading) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final filePath = file.path;
    if (filePath == null) return;

    if (!context.mounted) return;
    _showUploadDialog(context, file.name, filePath);
  }

  void _showUploadDialog(
      BuildContext context, String fileName, String localPath) {
    final destinationController =
        TextEditingController(text: '/home/worker/$fileName');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return TerminalDialog(
          title: context.l10n.terminalSftpTitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerminalText(
                'FILE: $fileName',
              ),
              VSpace.x2,
              TerminalTextField(
                controller: destinationController,
                label: context.l10n.terminalDestinationPath,
                hint: '/home/worker/$fileName',
              ),
            ],
          ),
          actions: [
            TerminalButton(
              label: context.l10n.actionCancel,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
            HSpace.x2,
            TerminalButton(
              label: context.l10n.terminalUpload,
              onTap: () {
                Navigator.of(dialogContext).pop();
                context.read<SshTerminalCubit>().uploadFile(
                      localPath: localPath,
                      remotePath: destinationController.text,
                      fileName: fileName,
                    );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatus(BuildContext context) {
    return BlocBuilder<StatusCubit, StatusState>(builder: (context, state) {
      final isConnected = state.isConnected;
      return BiosSection(
        title: context.l10n.terminalConnectionStatus,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TerminalText.mini(
              context.l10n.terminalSshLink(context.read<SshTerminalCubit>().sshHost, '${SshTerminalCubit.sshPort}'),
            ),
            TerminalText.label(
              '[ ${isConnected ? context.l10n.terminalOnline : context.l10n.terminalOffline} ]',
              color: isConnected
                  ? context.terminalColors.warning
                  : context.terminalColors.danger,
            ),
          ],
        ),
      );
    });
  }
}
