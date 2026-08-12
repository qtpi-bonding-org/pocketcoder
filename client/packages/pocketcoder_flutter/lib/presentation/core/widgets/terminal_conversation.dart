import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';

enum TerminalConversationSpeaker { user, poco }

class TerminalRoleLabel extends StatelessWidget {
  const TerminalRoleLabel({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: AppFonts.bodyFamily,
        fontSize: AppSizes.fontTiny,
        fontWeight: AppFonts.heavy,
        letterSpacing: 2,
      ),
    );
  }
}

/// A terminal-styled conversation turn shared by live and guided flows.
///
/// The widget does not own message state or submission behavior. A live-chat
/// adapter can supply streamed/agent-backed content, while a walkthrough
/// adapter can supply prepared local turns.
class TerminalConversationTurn extends StatelessWidget {
  const TerminalConversationTurn({
    super.key,
    required this.speaker,
    required this.message,
    this.sequence = PocoExpressions.happy,
  });

  final TerminalConversationSpeaker speaker;
  final String message;
  final List<(String, int)> sequence;

  @override
  Widget build(BuildContext context) {
    if (speaker == TerminalConversationSpeaker.poco) {
      return PocoBubble(
        message: message,
        sequence: sequence,
        pocoSize: AppSizes.fontLarge,
      );
    }

    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(
            color: terminalColors.user.withValues(alpha: 0.45),
          ),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
        child: Text(
          '\$ $message',
          style: TextStyle(
            color: terminalColors.user,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
          ),
        ),
      ),
    );
  }
}

/// A suggested local prompt. It intentionally looks like a terminal command
/// row instead of a modern rounded chip.
class TerminalPromptSuggestion extends StatelessWidget {
  const TerminalPromptSuggestion({
    super.key,
    required this.label,
    required this.onSelected,
  });

  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onSelected,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space,
            vertical: AppSizes.space,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: colors.primary.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: Text(
          '> ${label.toUpperCase()}',
          style: TextStyle(
            color: colors.primary,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ),
    );
  }
}
