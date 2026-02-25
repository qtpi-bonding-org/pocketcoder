import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/chat/communication_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/communication_state.dart';
import 'package:pocketcoder_flutter/application/permission/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/permission/permission_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_animator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_input.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/permission_prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/speech_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/thoughts_stream.dart';
import '../../app_router.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChatView();
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _inputController = TextEditingController();

  void _handleSubmit(BuildContext context) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    context.read<CommunicationCubit>().sendMessage('default', text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: UiFlowListener<CommunicationCubit, CommunicationState>(
            listener: (context, state) {
              if (state.chatId != null) {
                context.read<PermissionCubit>().watchChat(state.chatId!);
              }
            },
            child: Column(
              children: [
                BlocBuilder<CommunicationCubit, CommunicationState>(
                  builder: (context, state) {
                    return TerminalHeader(
                      title: state.chatId ?? 'POCKETCODER MAIN',
                    );
                  },
                ),
                VSpace.x1,
                // 1. TOP: The Thoughts / Cloud (Flexible height)
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.2),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.1),
                          width: AppSizes.borderWidth,
                        ),
                      ),
                    ),
                    child: BlocBuilder<CommunicationCubit, CommunicationState>(
                      builder: (context, state) {
                        final allMessages = [
                          ...state.messages,
                          if (state.hotMessage != null) state.hotMessage!
                        ];

                        final assistantMessages = allMessages
                            .where((m) => m.role == MessageRole.assistant);

                        final List<dynamic> brainParts = [];

                        for (final msg in assistantMessages) {
                          final parts = msg.parts ?? [];
                          if (parts.isEmpty) continue;
                          brainParts.addAll(parts);
                        }

                        return BiosSection(
                          title: 'REASONING_ENGINE',
                          child: Expanded(
                            child: ThoughtsStream(parts: brainParts),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. MIDDLE: Poco (The Entity)
                Container(
                  height: 120,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const PocoAnimator(
                      fontSize: 14), // Smaller, integrated face
                ),

                // 3. BOTTOM: The Dialogue (History)
                Expanded(
                  flex: 4,
                  child: BlocBuilder<CommunicationCubit, CommunicationState>(
                    builder: (context, state) {
                      // We need to reverse the list to stick to bottom
                      final reversedMessages = state.messages.reversed.toList();

                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.zero,
                        itemCount: reversedMessages.length,
                        itemBuilder: (context, index) {
                          final msg = reversedMessages[index];

                          // Filter text parts manually
                          final textParts = (msg.parts ?? []).where((p) {
                            return p is Map && p['type'] == 'text';
                          }).toList();

                          // For USER: Show all text.
                          if (msg.role == MessageRole.user) {
                            return SpeechBubble(
                                textParts: textParts, isUser: true);
                          }

                          // For ASSISTANT: Show ONLY the LAST text part.
                          // (Hide reasoning/tools from speech bubble)
                          final finalAnswer = textParts.isNotEmpty
                              ? [textParts.last]
                              : <dynamic>[];

                          return SpeechBubble(
                              textParts: finalAnswer, isUser: false);
                        },
                      );
                    },
                  ),
                ),

                // 3.5 GATEKEEPER PROMPT (Conditional)
                BlocBuilder<PermissionCubit, PermissionState>(
                  builder: (context, state) {
                    return state.maybeWhen(
                      loaded: (requests) {
                        if (requests.isEmpty) return const SizedBox.shrink();
                        // Show the oldest request first
                        final request = requests.first;
                        return PermissionPrompt(
                          request: request,
                          onAuthorize: () => context
                              .read<PermissionCubit>()
                              .authorize(request.id),
                          onDeny: () =>
                              context.read<PermissionCubit>().deny(request.id),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),

                // 4. INPUT
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: BlocBuilder<CommunicationCubit, CommunicationState>(
                    builder: (context, state) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.isLoading) ...[
                            const TerminalLoadingIndicator(label: 'THINKING'),
                            VSpace.x1,
                          ],
                          TerminalInput(
                            controller: _inputController,
                            onSubmitted: () => _handleSubmit(context),
                            prompt: 'SAY:',
                            enabled: !state.isLoading && state.chatId != null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            label: 'ARTIFACTS',
            onTap: () => context.goNamed(RouteNames.artifact),
          ),
          TerminalAction(
            label: 'TERMINAL',
            onTap: () => context.goNamed(RouteNames.terminal),
          ),
          TerminalAction(
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
          TerminalAction(
            label: 'LOGOUT',
            onTap: () => context.goNamed(RouteNames.boot),
          ),
        ],
      ),
    );
  }
}
