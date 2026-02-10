import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/app/bootstrap.dart';
import 'package:test_app/application/chat/chat_cubit.dart';
import 'package:test_app/application/chat/chat_state.dart';
import 'package:test_app/presentation/core/widgets/poco_animator.dart';
import 'package:test_app/presentation/chat/widgets/thoughts_stream.dart';
import 'package:test_app/presentation/chat/widgets/speech_bubble.dart';
import 'package:test_app/application/permission/permission_cubit.dart';
import 'package:test_app/application/permission/permission_state.dart';
import 'package:test_app/presentation/chat/widgets/permission_prompt.dart';

import '../../app_router.dart';

import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';

import '../../domain/chat/chat_message.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/terminal_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<ChatCubit>()..initialize()),
        BlocProvider(create: (context) => getIt<PermissionCubit>()),
      ],
      child: const _ChatView(),
    );
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

    context.read<ChatCubit>().sendMessage('default', text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary,
      body: ScanlineWidget(
        child: SafeArea(
          child: MultiBlocListener(
            listeners: [
              BlocListener<ChatCubit, ChatState>(
                listenWhen: (prev, curr) => prev.chatId != curr.chatId,
                listener: (context, state) {
                  if (state.chatId != null) {
                    context.read<PermissionCubit>().watchChat(state.chatId!);
                  }
                },
              ),
              BlocListener<ChatCubit, ChatState>(
                listenWhen: (prev, curr) =>
                    prev.error != curr.error && curr.error != null,
                listener: (context, state) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error!),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ],
            child: Column(
              children: [
                // 1. TOP: The Thoughts / Cloud (Flexible height)
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border(
                        bottom: BorderSide(
                          color: AppPalette.primary.textPrimary
                              .withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: BlocBuilder<ChatCubit, ChatState>(
                      builder: (context, state) {
                        // Collect ALL thoughts from history + current hot message
                        final allMessages = [
                          ...state.messages,
                          if (state.hotMessage != null) state.hotMessage!
                        ];

                        final assistantMessages = allMessages
                            .where((m) => m.role == MessageRole.assistant);

                        final List<MessagePart> brainParts = [];

                        for (final msg in assistantMessages) {
                          final parts = msg.parts ?? [];
                          if (parts.isEmpty) continue;

                          // If it's the HOT message (still thinking), show everything!
                          if (msg.isLive) {
                            brainParts.addAll(parts);
                            continue;
                          }

                          // For finalized messages:
                          // Show EVERYTHING in the brain log (redundancy is fine).
                          brainParts.addAll(parts);
                        }

                        return ThoughtsStream(parts: brainParts);
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
                  child: BlocBuilder<ChatCubit, ChatState>(
                    builder: (context, state) {
                      // We need to reverse the list to stick to bottom
                      final reversedMessages = state.messages.reversed.toList();

                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.zero,
                        itemCount: reversedMessages.length,
                        itemBuilder: (context, index) {
                          final msg = reversedMessages[index];

                          // For USER: Show all text.
                          if (msg.role == MessageRole.user) {
                            final textParts = (msg.parts ?? [])
                                .whereType<MessagePartText>()
                                .toList();
                            return SpeechBubble(
                                textParts: textParts, isUser: true);
                          }

                          // For ASSISTANT: Show ONLY the LAST text part.
                          // (Hide reasoning/tools from speech bubble)
                          final textParts = (msg.parts ?? [])
                              .whereType<MessagePartText>()
                              .toList();
                          final finalAnswer = textParts.isNotEmpty
                              ? [textParts.last]
                              : <MessagePartText>[];

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
                  child: BlocBuilder<ChatCubit, ChatState>(
                    builder: (context, state) {
                      return TerminalInput(
                        controller: _inputController,
                        onSubmitted: () => _handleSubmit(context),
                        prompt: 'SAY:',
                        enabled: !state.isLoading && state.chatId != null,
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
            keyLabel: 'F1',
            label: 'ARTIFACTS',
            onTap: () => context.goNamed(RouteNames.artifact),
          ),
          TerminalAction(
            keyLabel: 'F2',
            label: 'TERMINAL',
            onTap: () => context.goNamed(RouteNames.terminal),
          ),
          TerminalAction(
            keyLabel: 'F3',
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
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
}
