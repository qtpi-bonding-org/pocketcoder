import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart' as ag_ui_widgets;
import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/mode_switcher.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/plan_panel.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.chatId,
    required this.conversation,
    required this.title,
    required this.isLoading,
    required this.isRunning,
    required this.modes,
    required this.config,
    required this.onOpen,
    required this.onSendPrompt,
    required this.onCancel,
    required this.onSelectMode,
    required this.onSetOption,
    required this.onPermissionOptionSelected,
    required this.onElicitationRespond,
    required this.onFiles,
  });

  final String? chatId;
  final ag_ui_widgets.Conversation conversation;
  final String title;
  final bool isLoading;
  final bool isRunning;
  final Map<String, dynamic>? modes;
  final Map<String, dynamic>? config;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onSendPrompt;
  final VoidCallback onCancel;
  final ValueChanged<String> onSelectMode;
  final void Function(SetSessionConfigOptionRequest request) onSetOption;
  final void Function(String requestId, {String? optionId, bool cancelled})
      onPermissionOptionSelected;
  final void Function(String requestId, Map<String, dynamic> response)
      onElicitationRespond;
  final VoidCallback onFiles;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _inputController = TextEditingController();
  bool _opened = false;
  bool _sessionPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _openIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatId != oldWidget.chatId) {
      _opened = false;
      _openIfNeeded();
    }
  }

  void _openIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _opened) return;
      final id = widget.chatId;
      if (id == null || id.isEmpty || id == 'new') return;
      _opened = true;
      widget.onOpen(id);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String? _latestReasoningId(List<ag_ui_widgets.TimelineItem> timeline) {
    for (final item in timeline.reversed) {
      switch (item) {
        case ag_ui_widgets.TextTimelineItem(:final id, :final kind)
            when kind == ag_ui_widgets.ChatMessageKind.reasoning:
          return id;
        case ag_ui_widgets.TextStreamTimelineItem(:final id, :final kind)
            when kind == ag_ui_widgets.ChatMessageKind.reasoning:
          return id;
        default:
          continue;
      }
    }
    return null;
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    widget.onSendPrompt(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final builders = pocketcoderChatBuilders(
      context,
      latestReasoningId: _latestReasoningId(widget.conversation.timeline),
      onPermissionOptionSelected: widget.onPermissionOptionSelected,
      onElicitationRespond: widget.onElicitationRespond,
    );
    return PocketCoderShell(
      title: widget.title,
      activePillar: NavPillar.chats,
      showBack: true,
      extraHeaderActions: [
        TerminalAction(label: context.l10n.chatFilesAction, onTap: widget.onFiles),
        TerminalAction(
          label: 'SESSION',
          isActive: _sessionPanelExpanded,
          onTap: () => setState(() => _sessionPanelExpanded = !_sessionPanelExpanded),
        ),
        if (widget.isRunning)
          TerminalAction(label: 'CANCEL', onTap: widget.onCancel),
      ],
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          if (_sessionPanelExpanded) ...[
            PlanPanel(plan: widget.conversation.sessionState.plan),
            ModeSwitcher(modes: widget.modes, onSelectMode: widget.onSelectMode),
            ConfigPicker(config: widget.config, onSetOption: widget.onSetOption),
          ],
          Expanded(
            child: Stack(
              children: [
                ag_ui_widgets.AgUiChat(
                  conversation: widget.conversation,
                  currentUserId: 'user',
                  onSendMessage: widget.onSendPrompt,
                  theme: ag_ui_widgets.ChatTheme.fromThemeData(Theme.of(context)),
                  textMessageBuilder: builders.textMessageBuilder,
                  textStreamMessageBuilder: builders.textStreamMessageBuilder,
                  toolCallBuilder: builders.toolCallBuilder,
                  permissionBuilder: builders.permissionBuilder,
                  elicitationBuilder: builders.elicitationBuilder,
                  toolRequestBuilder: builders.toolRequestBuilder,
                  composerBuilder: (context) => Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoading) ...[
                          TerminalLoadingIndicator(label: context.l10n.chatThinking),
                          VSpace.x1,
                        ],
                        _SimpleInput(
                          controller: _inputController,
                          enabled: !widget.isLoading && widget.chatId != null,
                          onSubmitted: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.conversation.timeline.isEmpty)
                  IgnorePointer(
                    child: Center(
                      child: Text(
                        context.l10n.chatSessionTitle,
                        style: TextStyle(
                          color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                          fontSize: AppSizes.fontStandard,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleInput extends StatelessWidget {
  const _SimpleInput({required this.controller, required this.enabled, required this.onSubmitted});
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.onSurface.withValues(alpha: 0.2), width: AppSizes.borderWidth)),
      ),
      child: Row(children: [
        Text('\$ ', style: TextStyle(color: enabled ? terminalColors.attention : colors.onSurface.withValues(alpha: 0.3), fontFamily: AppFonts.bodyFamily, package: 'pocketcoder_flutter', fontSize: AppSizes.fontStandard, fontWeight: AppFonts.heavy)),
        Expanded(child: TextField(
          enabled: enabled,
          controller: controller,
          onSubmitted: (_) => onSubmitted(),
          style: TextStyle(color: terminalColors.attention, fontFamily: AppFonts.bodyFamily, package: 'pocketcoder_flutter', fontSize: AppSizes.fontStandard),
          cursorColor: terminalColors.attention,
          decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, filled: false),
        )),
        IconButton(
          onPressed: enabled ? onSubmitted : null,
          tooltip: 'Send',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: AppSizes.buttonHeight,
            minHeight: AppSizes.buttonHeight,
          ),
          icon: Text(
            '>',
            style: TextStyle(
              color: enabled ? terminalColors.attention : colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
            ),
          ),
        ),
      ]),
    );
  }
}
