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
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/question/question_cubit.dart';
import 'package:pocketcoder_flutter/application/question/question_state.dart';
import 'package:pocketcoder_flutter/application/llm/llm_cubit.dart';
import 'package:pocketcoder_flutter/application/llm/llm_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
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
              title: commState.chats
                      .where((c) => c.id == commState.chatId)
                      .map((c) => c.title)
                      .firstOrNull
                      ?.toUpperCase() ??
                  'CHAT SESSION',
              activePillar: NavPillar.chats,
              showBack: true,
              configureBadge: hasPendingMcp,
              padding: EdgeInsets.zero,
              extraHeaderActions: [
                TerminalAction(
                  label: 'TERMINAL',
                  onTap: () => AppNavigation.toTerminal(context),
                ),
                TerminalAction(
                  label: 'FILES',
                  onTap: () => AppNavigation.toFiles(context),
                ),
              ],
              body: MultiBlocListener(
                listeners: [
                  BlocListener<ChatCubit, ChatState>(
                    listenWhen: (previous, current) =>
                        previous.chatId != current.chatId,
                    listener: (context, state) {
                      final chatId = state.chatId;
                      if (chatId != null) {
                        context
                            .read<PermissionCubit>()
                            .watchChat(chatId);
                        context.read<QuestionCubit>().watchChat(chatId);
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

                    // 3.7 MODEL SELECTOR
                    _buildModelSelector(context, commState),

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

  Widget _buildModelSelector(BuildContext context, ChatState commState) {
    return BlocBuilder<LlmCubit, LlmState>(
      builder: (context, llmState) {
        if (llmState.providers.isEmpty) return const SizedBox.shrink();

        // Find current model for this chat (or global default)
        final chatModel = llmState.configs
            .where((c) => c.chat == commState.chatId)
            .toList();
        final globalModel =
            llmState.configs.where((c) => c.chat == null).toList();
        final currentModel = chatModel.isNotEmpty
            ? chatModel.first.model
            : globalModel.isNotEmpty
                ? globalModel.first.model
                : null;
        final isPerChat = chatModel.isNotEmpty;

        // Collect available models from connected providers
        final connectedIds = llmState.keys.map((k) => k.providerId).toSet();
        final allModels = <String>[];
        for (final p in llmState.providers) {
          if (connectedIds.contains(p.providerId) && p.models is List) {
            allModels.addAll((p.models as List).map((m) => m.toString()));
          }
        }
        if (allModels.isEmpty) return const SizedBox.shrink();

        final colors = context.colorScheme;
        return GestureDetector(
          onTap: () => _showChatModelPicker(
              context, allModels, commState.chatId, currentModel),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2,
              vertical: AppSizes.space * 0.5,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.1),
                  width: AppSizes.borderWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'MODEL:',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: AppSizes.fontMini,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                HSpace.x1,
                Expanded(
                  child: Text(
                    currentModel?.toUpperCase() ?? 'DEFAULT',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.primary,
                      fontSize: AppSizes.fontMini,
                      fontWeight: AppFonts.heavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPerChat) ...[
                  Text(
                    '[CHAT]',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.3),
                      fontSize: AppSizes.fontMini,
                    ),
                  ),
                  HSpace.x1,
                ],
                Icon(
                  Icons.unfold_more,
                  size: 14,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatModelPicker(BuildContext context, List<String> models,
      String? chatId, String? currentModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return TerminalDialog(
          title: 'SELECT MODEL',
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length + 1, // +1 for "USE GLOBAL DEFAULT"
              itemBuilder: (ctx, index) {
                // First item: reset to global
                if (index == 0) {
                  return InkWell(
                    onTap: () {
                      // Setting model without chat = global
                      if (chatId != null) {
                        // To reset per-chat, set the global model
                        final globalModel = context
                            .read<LlmCubit>()
                            .state
                            .configs
                            .where((c) => c.chat == null)
                            .toList();
                        if (globalModel.isNotEmpty) {
                          context
                              .read<LlmCubit>()
                              .setModel(globalModel.first.model, chat: chatId);
                        }
                      }
                      Navigator.pop(dialogContext);
                    },
                    child: Container(
                      padding: EdgeInsets.all(AppSizes.space),
                      margin: EdgeInsets.only(bottom: AppSizes.space * 0.5),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'USE GLOBAL DEFAULT',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: colors.onSurface.withValues(alpha: 0.7),
                          fontSize: AppSizes.fontSmall,
                        ),
                      ),
                    ),
                  );
                }

                final model = models[index - 1];
                final isSelected = model == currentModel;
                return InkWell(
                  onTap: () {
                    context
                        .read<LlmCubit>()
                        .setModel(model, chat: chatId);
                    Navigator.pop(dialogContext);
                  },
                  child: Container(
                    padding: EdgeInsets.all(AppSizes.space),
                    margin: EdgeInsets.only(bottom: AppSizes.space * 0.5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.2),
                      ),
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.05)
                          : null,
                    ),
                    child: Text(
                      model.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: isSelected ? colors.primary : colors.onSurface,
                        fontWeight:
                            isSelected ? AppFonts.heavy : AppFonts.medium,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TerminalButton(
              label: 'CANCEL',
              isPrimary: false,
              onTap: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }
}
