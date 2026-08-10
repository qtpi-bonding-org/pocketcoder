// pocketcoderChatBuilders: wires this app's `StackedChatBuilders` config —
// pocketcoder's theme colors/fonts as a `StackedChatStyle` (plus the
// COMMANDER/POCO/THINKING `roleHeaderBuilder` extracted into
// `chat_message_bubble.dart`), and a `ChatActionCallbacks` whose
// `permissionCardBuilder`/`elicitationCardBuilder` point at pocketcoder's
// own `PermissionCard`/`ElicitationCard`; adapters supply their callbacks.
// `toolCallOverrides`/
// `toolRequestOverrides` are left empty. Tool calls use pocketcoder's
// terminal command card so commands are visible and output stays collapsed
// until the user expands it.
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
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'widgets/terminal_command_card.dart';

/// Builds this app's `StackedChatBuilders` config: pocketcoder's theme
/// colors/fonts as a `StackedChatStyle`, plus `ChatActionCallbacks` wired
/// to this chat's permission/elicitation action callbacks.
/// `permissionCardBuilder`/`elicitationCardBuilder` keep pocketcoder's
/// own `PermissionCard`/`ElicitationCard` (they read their cubits
/// internally) since those need a distinct deny action and decline/cancel
/// responses the package's generic cards don't support.
/// Tool calls use a terminal command card with lifecycle status and
/// collapsed output. Client-side tool requests remain on the package's
/// existing callback path.
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
    sentBackground: colors.surface.withValues(alpha: 0),
    receivedBackground: colors.surface.withValues(alpha: 0),
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
    permissionCardBuilder: (context, item) => PermissionCard(
      item: item,
      onSelect: onPermissionOptionSelected,
    ),
    elicitationCardBuilder: (context, item) => ElicitationCard(
      item: item,
      onRespond: onElicitationRespond,
    ),
  );

  return _PocketcoderChatBuilders(style, callbacks, latestReasoningId);
}

/// Intercepts only reasoning ("thinking") messages -- completed or still
/// streaming -- to render them as a collapsible [ThinkingBlock] instead of
/// the generic full-width bubble every other message kind still gets via the
/// inherited [StackedChatBuilders] behavior.
class _PocketcoderChatBuilders extends StackedChatBuilders {
  _PocketcoderChatBuilders(
      super.style, super.callbacks, this.latestReasoningId);

  final String? latestReasoningId;

  @override
  CustomCardBuilder get toolCallBuilder =>
      (context, message, index, {required isSentByMe, groupStatus}) {
        final metadata = message.metadata ?? const <String, dynamic>{};
        final name = metadata['name'] as String? ?? '';
        final args = metadata['args'] as String? ?? '';
        final result = metadata['result'] as String?;
        final diffs = (metadata['diffs'] as List<dynamic>?) ?? const [];
        final command = args.trim().isEmpty ? name : '$name $args';
        return TerminalCommandCard(
          command: command,
          status:
              result == null ? TerminalStatus.running : TerminalStatus.success,
          outputLabel: context.l10n.chatCommandOutput,
          output: result,
          diffs: diffs,
        );
      };

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
