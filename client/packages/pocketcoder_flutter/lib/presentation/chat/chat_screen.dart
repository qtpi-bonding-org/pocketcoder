// ChatScreen: renders the reduced Conversation (ordered timeline + session
// state surfaces) from ChatCubit via BlocBuilder<ChatCubit, ChatState>,
// using flutter_chat_ui's Chat widget for the message list instead of a
// hand-rolled ListView. Sub-surfaces (mode, config, plan) stay as separate
// widgets around it -- they're session-wide chrome, not per-message.
// Permission/elicitation moved INTO the timeline (see
// docs/superpowers/specs/2026-07-21-flutter-chat-ui-migration-design.md):
// PermissionCard/ElicitationCard render via customMessageBuilder now,
// instead of as standalone banners below the list.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart' as ag_ui_widgets;
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/mode_switcher.dart';
import 'package:pocketcoder_flutter/presentation/agent/plan_panel.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';

class ChatScreen extends StatelessWidget {
  final String? chatId;

  const ChatScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatCubit>(create: (_) => getIt<ChatCubit>()),
        BlocProvider<PermissionCubit>(create: (_) => getIt<PermissionCubit>()),
        BlocProvider<ElicitationCubit>(create: (_) => getIt<ElicitationCubit>()),
        BlocProvider<SessionControlsCubit>(
            create: (_) => getIt<SessionControlsCubit>()),
      ],
      child: _ChatView(chatId: chatId),
    );
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
            TerminalAction(
              label: context.l10n.chatFilesAction,
              onTap: () => AppNavigation.toFiles(context),
            ),
            if (isRunning)
              TerminalAction(
                label: 'CANCEL',
                onTap: () => context.read<ChatCubit>().cancel(),
              ),
          ],
          padding: EdgeInsets.zero,
          body: MultiBlocListener(
            listeners: [
              BlocListener<ChatCubit, ChatState>(
                listenWhen: (previous, current) =>
                    previous.error != current.error && current.error != null,
                listener: (context, state) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${state.error}')),
                  );
                },
              ),
            ],
            child: Column(
              children: [
                const PlanPanel(),
                const ModeSwitcher(),
                const ConfigPicker(),
                Expanded(
                  child: (() {
                    final builders = pocketcoderChatBuilders(
                      context,
                      onPermissionOptionSelected:
                          (requestId, {optionId, cancelled = false}) {
                        final cubit = context.read<PermissionCubit>();
                        if (cancelled || optionId == null) {
                          cubit.deny();
                        } else {
                          cubit.authorize(optionId);
                        }
                      },
                      onElicitationRespond: (requestId, response) {
                        // ElicitationCard calls ElicitationCubit.submit directly via its
                        // own context.read — this callback only fires for a hypothetical
                        // future generic elicitation card, not the current override.
                      },
                    );
                    // AgUiChat has no built-in empty-state slot, so the
                    // placeholder is overlaid on top rather than swapped in
                    // for it -- the composer must stay mounted even with a
                    // zero-message timeline (a brand-new chat), or there's
                    // nowhere to type the first message.
                    return Stack(
                      children: [
                        ag_ui_widgets.AgUiChat(
                          conversation: commState.conversation,
                          currentUserId: 'user',
                          onSendMessage: (text) =>
                              context.read<ChatCubit>().sendPrompt(text),
                          // Unset, flutter_chat_ui falls back to a light
                          // theme regardless of the app's own dark theme —
                          // derive one from the ambient ThemeData so the
                          // message list background matches the terminal
                          // chrome instead of rendering white.
                          theme: ag_ui_widgets.ChatTheme.fromThemeData(
                              Theme.of(context)),
                          textMessageBuilder: builders.textMessageBuilder,
                          textStreamMessageBuilder:
                              builders.textStreamMessageBuilder,
                          toolCallBuilder: builders.toolCallBuilder,
                          permissionBuilder: builders.permissionBuilder,
                          elicitationBuilder: builders.elicitationBuilder,
                          toolRequestBuilder: builders.toolRequestBuilder,
                          composerBuilder: (context) => Padding(
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
                                _SimpleInput(
                                  controller: _inputController,
                                  enabled: !commState.isLoading &&
                                      commState.chatId != null,
                                  onSubmitted: () => _handleSubmit(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (commState.conversation.timeline.isEmpty)
                          IgnorePointer(
                            child: Center(
                              child: Text(
                                context.l10n.chatSessionTitle,
                                style: TextStyle(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                  fontSize: AppSizes.fontStandard,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  })(),
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
