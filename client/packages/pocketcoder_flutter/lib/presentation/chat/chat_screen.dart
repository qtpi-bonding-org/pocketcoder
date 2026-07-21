// ChatScreen (plan Task 13 Step 1): re-pointed at the AG-UI agent stack.
// Renders the reduced Conversation (messages + tool calls + session state
// surfaces) from the new ChatCubit (lib/application/agent/chat_cubit.dart)
// via BlocBuilder<ChatCubit, ChatState>. Sub-surfaces (permission, mode,
// config, elicitation, plan) are each their own widget that listens to the
// matching cubit. Cancelling an active run toggles the cancel button's
// visibility via state.status (UiFlowStatus.loading) + lastOperation.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/presentation/agent/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/elicitation_form.dart';
import 'package:pocketcoder_flutter/presentation/agent/mode_switcher.dart';
import 'package:pocketcoder_flutter/presentation/agent/plan_panel.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/permission_prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/app_router.dart';

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
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _opened) return;
      _opened = true;
      final id = widget.chatId;
      if (id == null || id.isEmpty || id == 'new') return;
      final chatCubit = context.read<ChatCubit>();
      chatCubit.open(id);
      context.read<PermissionCubit>().open(id);
      context.read<ElicitationCubit>().open(id);
      context.read<SessionControlsCubit>().open(id);
    });
  }

  @override
  void didUpdateWidget(covariant _ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatId != oldWidget.chatId &&
        widget.chatId != null &&
        widget.chatId!.isNotEmpty &&
        widget.chatId != 'new') {
      _opened = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _opened = true;
        final id = widget.chatId!;
        context.read<ChatCubit>().open(id);
        context.read<PermissionCubit>().open(id);
        context.read<ElicitationCubit>().open(id);
        context.read<SessionControlsCubit>().open(id);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _handleSubmit(BuildContext context) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final chatCubit = context.read<ChatCubit>();
    if (chatCubit.state.chatId == null) return;
    chatCubit.sendPrompt(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, commState) {
        final title = commState.conversation.sessionState.title ??
            context.l10n.chatSessionTitle;
        final isRunning = commState.status == UiFlowStatus.loading ||
            commState.lastOperation == AgentChatOperation.sendPrompt;

        return PocketCoderShell(
          title: title,
          activePillar: NavPillar.chats,
          showBack: true,
          extraHeaderActions: [
            if (isRunning)
              TerminalAction(
                label: 'CANCEL',
                onTap: () => context.read<ChatCubit>().cancel(),
              ),
            TerminalAction(
              label: context.l10n.chatTerminalAction,
              onTap: () => AppNavigation.toTerminal(context),
            ),
            TerminalAction(
              label: context.l10n.chatFilesAction,
              onTap: () => AppNavigation.toFiles(context),
            ),
          ],
          padding: EdgeInsets.zero,
          body: MultiBlocListener(
            listeners: [
              BlocListener<ChatCubit, ChatState>(
                listenWhen: (previous, current) =>
                    previous.error != current.error && current.error != null,
                listener: (context, state) {
                  // Surface a minimal error indication in the input area;
                  // the full UiFlowListener toast pipeline is wired at the
                  // app shell, not per-screen, so this is intentionally
                  // lightweight.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${state.error}')),
                  );
                },
              ),
            ],
            child: Column(
              children: [
                // ── Plan panel (renders only when SessionState.plan is published) ──
                const PlanPanel(),
                // ── Conversation list (text + reasoning + tool calls) ──
                Expanded(
                  child: _ConversationList(
                    messages: commState.conversation.messages,
                    toolCalls: commState.conversation.toolCalls,
                  ),
                ),
                // ── HITL surfaces (render only when their slice is present) ──
                const PermissionPrompt(),
                const ElicitationForm(),
                // ── Session controls (mode + config) ──
                const ModeSwitcher(),
                const ConfigPicker(),
                // ── Input area ──
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (commState.isLoading) ...[
                        TerminalLoadingIndicator(
                          label: context.l10n.chatThinking,
                        ),
                        VSpace.x1,
                      ],
                      // Bring up the keyboard-style input via a minimal
                      // text field — the legacy TerminalInput was designed
                      // for a different transport and would block submit
                      // here, so we keep the v1 surface minimal.
                      _SimpleInput(
                        controller: _inputController,
                        enabled: !commState.isLoading &&
                            commState.chatId != null,
                        onSubmitted: () => _handleSubmit(context),
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
  }
}

class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  const _SimpleInput({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.2),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '\$ ',
            style: TextStyle(
              color: enabled
                  ? terminalColors.attention
                  : colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Expanded(
            child: TextField(
              enabled: enabled,
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                color: terminalColors.attention,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontStandard,
              ),
              cursorColor: terminalColors.attention,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  final List<ChatMessage> messages;
  final List<ToolCall> toolCalls;

  const _ConversationList({
    required this.messages,
    required this.toolCalls,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    if (messages.isEmpty && toolCalls.isEmpty) {
      return Center(
        child: Text(
          context.l10n.chatSessionTitle,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.3),
            fontSize: AppSizes.fontStandard,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space),
      itemCount: messages.length + toolCalls.length,
      itemBuilder: (context, index) {
        final toolOffset = messages.length;
        if (index >= toolOffset) {
          final tool = toolCalls[index - toolOffset];
          return _ToolCallCard(tool: tool);
        }
        final msg = messages[index];
        return _ChatMessageTile(message: msg);
      },
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final isReasoning = message.kind == ChatMessageKind.reasoning;
    final isUser = message.role == 'user';
    final accent = isReasoning
        ? terminalColors.warning
        : isUser
            ? terminalColors.user
            : colors.primary;

    final label = isUser ? 'COMMANDER' : (isReasoning ? 'THINKING' : 'POCO');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.06),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                size: 14,
                color: accent,
              ),
              HSpace.x1,
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          VSpace.x1,
          Text(
            message.text,
            style: TextStyle(
              color: isReasoning
                  ? colors.onSurface.withValues(alpha: 0.7)
                  : colors.onSurface,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
              fontStyle: isReasoning ? FontStyle.italic : FontStyle.normal,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final ToolCall tool;

  const _ToolCallCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.space,
        vertical: AppSizes.space * 0.5,
      ),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.04),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                size: 14,
                color: terminalColors.attention,
              ),
              HSpace.x1,
              Text(
                tool.name.toUpperCase(),
                style: TextStyle(
                  color: terminalColors.attention,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          if (tool.args.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'ARGS: ${tool.args}',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (tool.result != null) ...[
            VSpace.x1,
            Text(
              'RESULT: ${tool.result}',
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
