import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

/// authorId used for every user-authored message.
const kUserAuthorId = 'user';

/// authorId used for every agent-authored message.
const kAgentAuthorId = 'assistant';

/// Renders pocketcoder's COMMANDER/POCO/THINKING terminal label row. The
/// uppercase label color depends on who's speaking and whether this is a
/// reasoning aside. Passed as `StackedChatStyle.roleHeaderBuilder` so both
/// completed and streaming messages get identical header treatment.
Widget pocketcoderRoleHeader(
  BuildContext context, {
  required String role,
  required bool isSentByMe,
  required bool isReasoning,
}) {
  final colors = context.colorScheme;
  final terminalColors = context.terminalColors;
  final accent = isReasoning
      ? terminalColors.warning
      : emphasize(colors.secondary,
                      isSentByMe ? Emphasis.selected : Emphasis.plain)
                  .text ==
              Colors.black
          ? colors.secondary
          : colors.primary;
  final label = isSentByMe
      ? context.l10n.chatCommanderRole
      : (isReasoning
          ? context.l10n.chatThinkingRole
          : context.l10n.chatPocoRole);

  return Padding(
    padding: EdgeInsets.only(bottom: AppSizes.space),
    child: Row(
      children: [
        TerminalRoleLabel(label: label, color: accent),
      ],
    ),
  );
}
