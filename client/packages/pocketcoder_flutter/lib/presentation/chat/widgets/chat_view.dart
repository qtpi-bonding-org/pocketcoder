import 'dart:async';

import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    as ag_ui_widgets;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/plan_panel.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_composer.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/reasoning_caption.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.chatId,
    required this.conversation,
    required this.title,
    required this.isLoading,
    this.awaitingHarnessStart = false,
    required this.isRunning,
    required this.requiresProviderReauthentication,
    required this.config,
    required this.showMonitorAction,
    required this.monitored,
    required this.onToggleMonitored,
    required this.onOpen,
    required this.onSendPrompt,
    required this.onCancel,
    required this.onSetOption,
    this.onSearchModels,
    required this.onPermissionOptionSelected,
    required this.onElicitationRespond,
    required this.animatedMessageIds,
    required this.onMessageAnimated,
    required this.onFiles,
    this.onRunStarted,
  });

  final String? chatId;
  final ag_ui_widgets.Conversation conversation;
  final String title;
  final bool isLoading;
  final bool awaitingHarnessStart;
  final bool isRunning;
  final bool requiresProviderReauthentication;
  final Map<String, dynamic>? config;
  final bool showMonitorAction;
  final bool monitored;
  final VoidCallback onToggleMonitored;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onSendPrompt;
  final VoidCallback onCancel;
  final void Function(SetSessionConfigOptionRequest request) onSetOption;
  final Future<List<HarnessModel>> Function()? onSearchModels;
  final void Function(String requestId, {String? optionId, bool cancelled})
      onPermissionOptionSelected;
  final void Function(String requestId, Map<String, dynamic> response)
      onElicitationRespond;
  final Set<String> animatedMessageIds;
  final ValueChanged<String> onMessageAnimated;
  final VoidCallback onFiles;
  final Future<void> Function(String chatId)? onRunStarted;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _transcriptKey = GlobalKey<ag_ui_widgets.AgUiTranscriptState>();
  bool _opened = false;
  bool _reauthAnnounced = false;

  @override
  void initState() {
    super.initState();
    _openIfNeeded();
    _logWidgetMessageOrder('initState');
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.conversation, widget.conversation)) {
      _logWidgetMessageOrder('didUpdateWidget');
    }
    if (widget.chatId != oldWidget.chatId) {
      _opened = false;
      _openIfNeeded();
      return;
    }
    _provideRunCompletionHaptic(oldWidget);
    _startForegroundActivityIfNeeded(oldWidget);
    if (!widget.requiresProviderReauthentication) _reauthAnnounced = false;
    _announceReauthIfNeeded(oldWidget);
    _announceRunOutcomeIfNeeded(oldWidget);
  }

  void _logWidgetMessageOrder(String trigger) {
    final messages = ag_ui_widgets.timelineToMessages(widget.conversation.timeline);
    logDebug('🖼️ [ChatView] widget message order', {
      'trigger': trigger,
      'wallClock': DateTime.now().toIso8601String(),
      'messages': messages
          .map((m) => switch (m) {
                chat_core.TextMessage(:final id) => 'text:$id',
                chat_core.TextStreamMessage(:final id) => 'textStream:$id',
                chat_core.CustomMessage(:final id) => 'custom:$id',
                _ => 'other:${m.id}',
              })
          .toList(),
    });
  }

  void _provideRunCompletionHaptic(ChatView oldWidget) {
    final outcome = widget.conversation.sessionState.runOutcome;
    if (!oldWidget.isRunning || widget.isRunning || outcome == null) return;

    // A completed run gets a gentle acknowledgement. Errors and interrupted
    // runs use a slightly more noticeable pulse so they are distinguishable
    // when the user is away from the screen.
    unawaited((switch (outcome) {
      ag_ui_widgets.RunOutcome.success => HapticFeedback.lightImpact(),
      _ => HapticFeedback.mediumImpact(),
    }));
  }

  void _startForegroundActivityIfNeeded(ChatView oldWidget) {
    final chatId = widget.chatId;
    if (oldWidget.isRunning ||
        !widget.isRunning ||
        !widget.monitored ||
        chatId == null ||
        chatId.isEmpty ||
        chatId == 'new') {
      return;
    }
    final start = widget.onRunStarted;
    if (start != null) unawaited(start(chatId));
  }

  void _announceReauthIfNeeded(ChatView oldWidget) {
    if (oldWidget.requiresProviderReauthentication ||
        !widget.requiresProviderReauthentication ||
        _reauthAnnounced) {
      return;
    }
    _reauthAnnounced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      VimToast.show(
        context,
        context.l10n.providerReauthenticationRequired,
        color: context.terminalColors.warning,
      );
    });
  }

  void _announceRunOutcomeIfNeeded(ChatView oldWidget) {
    final outcome = widget.conversation.sessionState.runOutcome;
    if (outcome == null || outcome == ag_ui_widgets.RunOutcome.success) return;
    if (oldWidget.conversation.sessionState.runOutcome == outcome) return;

    final (title, body) = switch (outcome) {
      ag_ui_widgets.RunOutcome.interrupted => (
          context.l10n.chatRunOutcomeInterruptedTitle,
          context.l10n.chatRunOutcomeInterruptedBody,
        ),
      ag_ui_widgets.RunOutcome.cancelled => (
          context.l10n.chatRunOutcomeCancelledTitle,
          context.l10n.chatRunOutcomeCancelledBody,
        ),
      ag_ui_widgets.RunOutcome.failed => (
          context.l10n.chatRunOutcomeFailedTitle,
          context.l10n.chatRunOutcomeFailedBody,
        ),
      ag_ui_widgets.RunOutcome.success => ('', ''),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) VimToast.show(context, '$title: $body');
    });
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
    _inputFocusNode.dispose();
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

  String? _latestReasoningText(List<ag_ui_widgets.TimelineItem> timeline) {
    for (final item in timeline.reversed) {
      switch (item) {
        case ag_ui_widgets.TextTimelineItem(:final text, :final kind)
            when kind == ag_ui_widgets.ChatMessageKind.reasoning:
          return text;
        case ag_ui_widgets.TextStreamTimelineItem(:final text, :final kind)
            when kind == ag_ui_widgets.ChatMessageKind.reasoning:
          return text;
        default:
          continue;
      }
    }
    return null;
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _transcriptKey.currentState?.rearmFollow();
    widget.onSendPrompt(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final latestReasoningId = _latestReasoningId(widget.conversation.timeline);
    final latestReasoningText =
        _latestReasoningText(widget.conversation.timeline);
    final builders = pocketcoderChatBuilders(
      context,
      latestReasoningId: latestReasoningId,
      onPermissionOptionSelected: widget.onPermissionOptionSelected,
      onElicitationRespond: widget.onElicitationRespond,
      animatedMessageIds: widget.animatedMessageIds,
      onMessageAnimated: widget.onMessageAnimated,
    );

    final extraFooterActions = [
      TerminalAction(
        label: context.l10n.chatFilesAction,
        onTap: widget.onFiles,
        kind: ActionKind.neutral,
      ),
      if (widget.showMonitorAction)
        TerminalAction(
          label: context.l10n.chatMonitorAction,
          onTap: widget.onToggleMonitored,
          isActive: widget.monitored,
          kind: ActionKind.neutral,
        ),
    ];

    return PocketCoderShell(
      footer: buildPillarFooter(
        context,
        NavPillar.chat,
        extraActions: extraFooterActions,
      ),
      showBack: true,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          PlanPanel(plan: widget.conversation.sessionState.plan),
          ConfigPicker(
              config: widget.config,
              onSetOption: widget.onSetOption,
              onSearchModels: widget.onSearchModels),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isLoading && latestReasoningId == null)
                  ReasoningCaption(
                    text: widget.awaitingHarnessStart
                        ? context.l10n.chatAwaitingHarnessStart
                        : context.l10n.chatWorkingThroughRequest,
                    isStreaming: true,
                  )
                else if (latestReasoningText != null)
                  ReasoningCaption(
                    key: ValueKey(latestReasoningId),
                    text: latestReasoningText.trim(),
                    isStreaming: widget.isLoading,
                  ),
                if (widget.conversation.timeline.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
                    child: Center(
                      child: PocoFace(isAgentTurn: widget.isLoading),
                    ),
                  ),
                Expanded(
                  child: ag_ui_widgets.AgUiTranscript(
                    key: _transcriptKey,
                    conversation: widget.conversation,
                    currentUserId: 'user',
                    placement: ag_ui_widgets.ComposerPlacement.inline,
                    onTapEmptySpace: _inputFocusNode.unfocus,
                    theme: ag_ui_widgets.ChatTheme.fromThemeData(
                        Theme.of(context)),
                    textMessageBuilder: builders.textMessageBuilder,
                    textStreamMessageBuilder: builders.textStreamMessageBuilder,
                    toolCallBuilder: builders.toolCallBuilder,
                    permissionBuilder: builders.permissionBuilder,
                    elicitationBuilder: builders.elicitationBuilder,
                    toolRequestBuilder: builders.toolRequestBuilder,
                    composerBuilder: (context) => ChatComposer(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      enabled: !widget.isLoading && widget.chatId != null,
                      isLoading: widget.isLoading,
                      onSubmitted: _submit,
                      onInterrupt: widget.isRunning ? widget.onCancel : null,
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
