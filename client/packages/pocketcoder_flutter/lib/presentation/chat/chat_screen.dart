import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/chat/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_state.dart';
import 'package:pocketcoder_flutter/application/permission/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/permission/permission_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_animator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_input.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/permission_prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/question_prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/speech_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/question/question_cubit.dart';
import 'package:pocketcoder_flutter/application/question/question_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class ChatScreen extends StatelessWidget {
  final String? chatId;

  const ChatScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context) {
    return _ChatView(chatId: chatId);
  }
}

class _ChatView extends StatefulWidget {
  final String? chatId;

  const _ChatView({this.chatId});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.chatId ?? 'new';
      context.read<ChatCubit>().loadChat(id);
    });
  }

  void _handleSubmit(BuildContext context) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatCubit>().sendMessage('default', text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, commState) {
        return BlocBuilder<McpCubit, McpState>(
          builder: (context, mcpState) {
            final hasPendingMcp = mcpState.maybeWhen(
              loaded: (servers) =>
                  servers.any((s) => s.status == McpServerStatus.pending),
              orElse: () => false,
            );

            return PocketCoderShell(
              title: commState.chatId ?? 'POCKETCODER MAIN',
              activePillar: NavPillar.chats,
              showBack: true,
              configureBadge: hasPendingMcp,
              padding: EdgeInsets.zero,
              body: MultiBlocListener(
                listeners: [
                  BlocListener<ChatCubit, ChatState>(
                    listenWhen: (previous, current) =>
                        previous.chatId != current.chatId,
                    listener: (context, state) {
                      if (state.chatId != null) {
                        context
                            .read<PermissionCubit>()
                            .watchChat(state.chatId!);
                        context.read<QuestionCubit>().watchChat(state.chatId!);
                      }
                    },
                  ),
                  BlocListener<McpCubit, McpState>(
                    listenWhen: (prev, curr) {
                      final prevPending = prev.maybeWhen(
                        loaded: (servers) => servers
                            .where((s) => s.status == McpServerStatus.pending)
                            .length,
                        orElse: () => 0,
                      );
                      final currPending = curr.maybeWhen(
                        loaded: (servers) => servers
                            .where((s) => s.status == McpServerStatus.pending)
                            .length,
                        orElse: () => 0,
                      );
                      return currPending > prevPending;
                    },
                    listener: (context, state) {
                      getIt<IFeedbackService>().show(const FeedbackMessage(
                        message: '[!] NEW CAPABILITY REQUEST RECEIVED',
                        type: MessageType.warning,
                      ));
                    },
                  ),
                ],
                child: Column(
                  children: [
                    // 2. MIDDLE: Poco (The Entity)
                    Container(
                      height: 100,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: const PocoAnimator(fontSize: 12),
                    ),

                    // 3. BOTTOM: The Dialogue (History)
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.zero,
                        itemCount: commState.displayMessages.length,
                        itemBuilder: (context, index) {
                          final reversedMessages =
                              commState.displayMessages.reversed.toList();
                          final msg = reversedMessages[index];

                          return SpeechBubble(
                              message: msg,
                              isUser: msg.role == MessageRole.user);
                        },
                      ),
                    ),

                    // 3.5 GATEKEEPER PROMPT (Conditional)
                    BlocBuilder<PermissionCubit, PermissionState>(
                      builder: (context, state) {
                        return state.maybeWhen(
                          loaded: (requests) {
                            if (requests.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final request = requests.first;
                            return PermissionPrompt(
                              request: request,
                              onAuthorize: () => context
                                  .read<PermissionCubit>()
                                  .authorize(request.id),
                              onDeny: () => context
                                  .read<PermissionCubit>()
                                  .deny(request.id),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
                    ),

                    // 3.6 QUESTION PROMPT (Conditional)
                    BlocBuilder<QuestionCubit, QuestionState>(
                      builder: (context, state) {
                        return state.maybeWhen(
                          loaded: (questions) {
                            if (questions.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final question = questions.first;
                            return QuestionPrompt(
                              question: question,
                              onAnswer: (reply) => context
                                  .read<QuestionCubit>()
                                  .answer(question.id, reply),
                              onReject: () => context
                                  .read<QuestionCubit>()
                                  .reject(question.id),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
                    ),

                    // 4. INPUT
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (commState.isLoading) ...[
                            const TerminalLoadingIndicator(label: 'THINKING'),
                            VSpace.x1,
                          ],
                          TerminalInput(
                            controller: _inputController,
                            onSubmitted: () => _handleSubmit(context),
                            prompt: '\$',
                            enabled: !commState.isLoading &&
                                commState.chatId != null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
