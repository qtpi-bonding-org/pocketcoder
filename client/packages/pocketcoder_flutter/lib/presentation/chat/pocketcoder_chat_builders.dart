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
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'chat_message_bubble.dart' show pocketcoderRoleHeader;
import 'elicitation_card.dart';
import 'permission_card.dart';

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
  required void Function(String requestId, {String? optionId, bool cancelled}) onPermissionOptionSelected,
  required void Function(String requestId, Map<String, dynamic> response) onElicitationRespond,
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
    padding: EdgeInsets.symmetric(horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
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

  return StackedChatBuilders(style, callbacks);
}