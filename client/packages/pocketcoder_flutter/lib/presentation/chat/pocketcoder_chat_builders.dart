// pocketcoderChatBuilders: wires this app's `StackedChatBuilders` config —
// pocketcoder's theme colors/fonts as a `StackedChatStyle` (plus the
// COMMANDER/POCO/THINKING `roleHeaderBuilder` extracted into
// `chat_message_bubble.dart` in Task 2), and a `ChatActionCallbacks` whose
// `permissionCardBuilder`/`elicitationCardBuilder` point at pocketcoder's
// own `PermissionCard`/`ElicitationCard` (they read their cubits
// internally — no callback plumbing needed). `toolCallOverrides`/
// `toolRequestOverrides` are left empty: the package's generic tool-call
// card now renders diffs, and pocketcoder has no client-executed-tool
// feature yet, so the generic `toolRequestBuilder` fallback is a strict
// improvement over today's silent `SizedBox.shrink()`.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart'
    show StreamStateStreaming;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'chat_message_bubble.dart' show pocketcoderRoleHeader;
import 'elicitation_card.dart';
import 'permission_card.dart';
import 'thinking_block.dart';

/// Builds this app's `StackedChatBuilders` config: pocketcoder's theme
/// colors/fonts as a `StackedChatStyle`, plus `ChatActionCallbacks` wired
/// to this chat's permission/elicitation action callbacks.
/// `permissionCardBuilder`/`elicitationCardBuilder` keep pocketcoder's
/// own `PermissionCard`/`ElicitationCard` (they read their cubits
/// internally) since those need a distinct deny action and decline/cancel
/// responses the package's generic cards don't support.
/// `toolCallOverrides`/`toolRequestOverrides` are left empty — the generic
/// tool-call card now renders diffs, and pocketcoder has no
/// client-executed-tool feature yet.
StackedChatBuilders pocketcoderChatBuilders(
  BuildContext context, {
  required void Function(String requestId, {String? optionId, bool cancelled})
      onPermissionOptionSelected,
  required void Function(String requestId, Map<String, dynamic> response)
      onElicitationRespond,
  String? latestReasoningId,
}) {
  final colors = context.colorScheme;
  final terminalColors = context.terminalColors;

  final style = StackedChatStyle(
    sentBackground: Colors.transparent,
    receivedBackground: Colors.transparent,
    textStyle: TextStyle(
      color: colors.onSurface,
      fontFamily: AppFonts.bodyFamily,
      fontSize: AppSizes.fontStandard,
      height: 1.4,
    ),
    reasoningTextStyle: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.7),
      fontFamily: AppFonts.bodyFamily,
      fontSize: AppSizes.fontStandard,
      fontStyle: FontStyle.italic,
      height: 1.4,
    ),
    roleHeaderBuilder: pocketcoderRoleHeader,
    padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
    cardBorderColor: terminalColors.attention.withValues(alpha: 0.3),
    diffAddedColor: terminalColors.attention,
    diffRemovedColor: terminalColors.danger,
  );

  final callbacks = ChatActionCallbacks(
    onPermissionOptionSelected: onPermissionOptionSelected,
    onElicitationRespond: onElicitationRespond,
    permissionCardBuilder: (context, item) => PermissionCard(item: item),
    elicitationCardBuilder: (context, item) => ElicitationCard(item: item),
  );

  return _PocketcoderChatBuilders(style, callbacks, latestReasoningId);
}

/// Intercepts only reasoning ("thinking") messages -- completed or still
/// streaming -- to render them as a collapsible [ThinkingBlock] with a Poco
/// avatar, instead of the generic full-width bubble every other message
/// kind still gets via the inherited [StackedChatBuilders] behavior.
class _PocketcoderChatBuilders extends StackedChatBuilders {
  _PocketcoderChatBuilders(
      super.style, super.callbacks, this.latestReasoningId);

  final String? latestReasoningId;

  bool _isReasoning(chat_core.Message message) =>
      message.metadata?['kind'] == 'reasoning';

  @override
  chat_core.TextMessageBuilder get textMessageBuilder =>
      (context, message, index, {required isSentByMe, groupStatus}) {
        if (_isReasoning(message)) {
          return ThinkingBlock(
            key: ValueKey(message.id),
            text: message.text,
            isLatest: message.id == latestReasoningId,
            isStreaming: false,
          );
        }
        return super.textMessageBuilder(context, message, index,
            isSentByMe: isSentByMe, groupStatus: groupStatus);
      };

  @override
  TextStreamCardBuilder get textStreamMessageBuilder =>
      (context, message, index,
          {required isSentByMe, groupStatus, required streamState}) {
        if (_isReasoning(message)) {
          return ThinkingBlock(
            key: ValueKey(message.id),
            text: streamState is StreamStateStreaming
                ? streamState.accumulatedText
                : '',
            isLatest: message.id == latestReasoningId,
            isStreaming: true,
          );
        }
        return super.textStreamMessageBuilder(context, message, index,
            isSentByMe: isSentByMe,
            groupStatus: groupStatus,
            streamState: streamState);
      };
}
