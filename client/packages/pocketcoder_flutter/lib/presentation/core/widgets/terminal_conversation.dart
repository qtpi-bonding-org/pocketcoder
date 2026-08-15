import 'package:flutter/material.dart';
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

/// Shared terminal frame for a conversation message.
///
/// The message body remains caller-owned so live AG-UI messages can keep
/// their markdown/streaming renderer while scripted onboarding can use plain
/// terminal turns. State and submission behavior stay outside this widget.
class TerminalConversationFrame extends StatelessWidget {
  const TerminalConversationFrame({
    super.key,
    required this.speaker,
    required this.child,
    this.roleLabel,
    this.isReasoning = false,
  });

  final TerminalConversationSpeaker speaker;
  final Widget child;
  final String? roleLabel;
  final bool isReasoning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final isUser = speaker == TerminalConversationSpeaker.user;
    final accent = isReasoning
        ? terminalColors.warning
        : isUser
            ? terminalColors.user
            : colors.primary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (roleLabel != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: TerminalRoleLabel(label: roleLabel!, color: accent),
          ),
        child,
      ],
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        padding: EdgeInsets.all(AppSizes.space),
        decoration: isUser
            ? BoxDecoration(
                border: Border.all(
                  color: terminalColors.user.withValues(alpha: 0.45),
                ),
                color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
              )
            : null,
        child: content,
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
    this.sequence = const [],
    this.history = const [],
  });

  final TerminalConversationSpeaker speaker;
  final String message;
  final List<(String, int)> sequence;
  final List<String> history;

  @override
  Widget build(BuildContext context) {
    if (speaker == TerminalConversationSpeaker.poco) {
      return TerminalConversationFrame(
        speaker: speaker,
        child: PocoBubble(
          message: message,
          sequence: sequence,
          history: history,
          pocoSize: AppSizes.fontLarge,
        ),
      );
    }

    return TerminalConversationFrame(
      speaker: speaker,
      child: Text(
        '\$ $message',
        style: TextStyle(
          color: context.terminalColors.user,
          fontFamily: AppFonts.bodyFamily,
          fontSize: AppSizes.fontStandard,
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
