import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/chat/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_state.dart';

class FileScreen extends StatefulWidget {
  final String? initialPath;

  const FileScreen({super.key, this.initialPath});

  @override
  State<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends State<FileScreen> {
  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatCubit>().fetchFileContent(path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<ChatCubit, ChatState>(
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          return PocketCoderShell(
            title: 'SOURCE OUTPUT MANIFEST',
            activePillar: NavPillar.chats,
            showBack: true,
            extraHeaderActions: [
              TerminalAction(
                label: 'DASHBOARD',
                onTap: () => context.goNamed(RouteNames.home),
              ),
              TerminalAction(
                label: 'CLEAR',
                onTap: () => context.read<ChatCubit>().clearFile(),
              ),
            ],
            body: BiosFrame(
              title: state.currentFilePath ?? 'FILES',
              child: _buildFileContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, ChatState state) {
    final colors = context.colorScheme;

    if (state.currentFilePath == null) {
      return Center(
        child: BiosSection(
          title: 'REGISTRY STATUS',
          child: Column(
            children: [
              TerminalText(
                'NO FILE SELECTED.',
                alpha: 0.5,
              ),
              TerminalText.mini(
                '>> SELECT FROM CHAT TO VIEW',
                alpha: 0.5,
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoading) {
      return Center(
        child: TerminalText(
          'FETCHING DATA...',
          color: colors.primary,
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.space),
      child: TerminalText(
        state.currentFileContent ?? 'EMPTY FILE',
        size: TerminalTextSize.base,
      ),
    );
  }
}
