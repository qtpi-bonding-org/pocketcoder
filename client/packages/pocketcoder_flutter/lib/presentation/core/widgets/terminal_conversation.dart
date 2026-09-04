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
        fontFamily: AppFonts.family,
        fontSize: AppSizes.fontBody,
        fontWeight: AppFonts.heavy,
        letterSpacing: 2,
      ),
    );
  }
}

/// A single terminal transcript line with a semantic speaker prefix.
class TerminalTranscriptLine extends StatelessWidget {
  const TerminalTranscriptLine({
    super.key,
    required this.prefix,
    required this.child,
    required this.color,
  });

  final String prefix;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: TextStyle(
            color: color,
            fontFamily: AppFonts.family,
            package: 'pocketcoder_flutter',
            fontSize: AppSizes.fontBody,
            fontWeight: AppFonts.medium,
          ),
        ),
        Expanded(child: child),
      ],
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
    this.showUserBorder = true,
  });

  final TerminalConversationSpeaker speaker;
  final Widget child;
  final String? roleLabel;
  final bool isReasoning;
  final bool showUserBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final isUser = speaker == TerminalConversationSpeaker.user;
    final resolved =
        emphasize(colors.secondary, isUser ? Emphasis.selected : Emphasis.plain);
    final accent = isReasoning ? terminalColors.warning : resolved.text;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (roleLabel case final resolvedRoleLabel?)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: TerminalRoleLabel(label: resolvedRoleLabel, color: accent),
          ),
        child,
      ],
    );

    final frame = Container(
      constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: isUser && showUserBorder
          ? BoxDecoration(color: resolved.fill)
          : null,
      child: content,
    );

    // Every live-chat turn belongs to one left-aligned terminal transcript.
    // Poco messages still occupy a stable width before streamed text starts,
    // but neither speaker should float to the right or center as content
    // changes.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, AppSizes.contentMaxWidth)
            : AppSizes.contentMaxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: width.toDouble(), child: frame),
        );
      },
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
    this.showPocoFace = true,
  });

  final TerminalConversationSpeaker speaker;
  final String message;
  final List<(String, int)> sequence;
  final List<String> history;
  final bool showPocoFace;

  @override
  Widget build(BuildContext context) {
    if (speaker == TerminalConversationSpeaker.poco) {
      return TerminalConversationFrame(
        speaker: speaker,
        child: PocoBubble(
          message: message,
          sequence: sequence,
          history: history,
          pocoSize: AppSizes.fontBody,
          showFace: showPocoFace,
        ),
      );
    }

    return TerminalConversationFrame(
      speaker: speaker,
      child: Text(
        '\$ $message',
        style: TextStyle(
          color: emphasize(context.colorScheme.secondary, Emphasis.selected).text,
          fontFamily: AppFonts.family,
          fontSize: AppSizes.fontBody,
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
    this.emphasis,
  });

  final String label;
  final VoidCallback onSelected;

  /// When set, routes the border/text color through emphasize() instead
  /// of the default alpha-0.3 border. See the emphasis-states spec
  /// (2026-08-23).
  final Emphasis? emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final resolvedEmphasis = emphasis;
    final resolved = resolvedEmphasis == null
        ? null
        : emphasize(colors.primary, resolvedEmphasis);
    final borderColor = resolved?.border ?? colors.primary.withValues(alpha: 0.3);
    final textColor = resolved?.text ?? colors.primary;
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
            side: BorderSide(color: borderColor),
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: Text(
          '> ${label.toUpperCase()}',
          style: TextStyle(
            color: textColor,
            fontFamily: AppFonts.family,
            fontSize: AppSizes.fontBody,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ),
    );
  }
}
