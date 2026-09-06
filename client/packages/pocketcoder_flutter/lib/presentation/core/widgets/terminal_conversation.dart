import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

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
    final resolved = emphasize(
        colors.secondary, isUser ? Emphasis.selected : Emphasis.plain);
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
      decoration:
          isUser && showUserBorder ? BoxDecoration(color: resolved.fill) : null,
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
    this.pocoSize,
  });

  final TerminalConversationSpeaker speaker;
  final String message;
  final List<(String, int)> sequence;
  final List<String> history;
  final bool showPocoFace;

  final double? pocoSize;

  @override
  Widget build(BuildContext context) {
    if (speaker == TerminalConversationSpeaker.poco) {
      return TerminalConversationFrame(
        speaker: speaker,
        child: PocoBubble(
          message: message,
          sequence: sequence,
          history: history,
          showFace: showPocoFace,
          pocoSize: pocoSize,
        ),
      );
    }

    return TerminalConversationFrame(
      speaker: speaker,
      child: Text(
        '\$ $message',
        style: TextStyle(
          color:
              emphasize(context.colorScheme.secondary, Emphasis.selected).text,
          fontFamily: AppFonts.family,
        ),
      ),
    );
  }
}

/// A suggested local prompt with user's voice represented as a prompt marker (>).
class TerminalPromptSuggestion extends StatefulWidget {
  const TerminalPromptSuggestion({
    super.key,
    required this.label,
    required this.onSelected,
    this.emphasis,
  });

  final String label;
  final VoidCallback onSelected;

  final Emphasis? emphasis;

  @override
  State<TerminalPromptSuggestion> createState() =>
      _TerminalPromptSuggestionState();
}

class _TerminalPromptSuggestionState extends State<TerminalPromptSuggestion> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final role = (widget.emphasis == Emphasis.outlined
            ? ActionKind.primary
            : ActionKind.neutral)
        .role;
    final reversed = _pressed;

    return GestureDetector(
      onTap: widget.onSelected,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        width: double.infinity,
        color: reversed ? role.color : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space,
          vertical: AppSizes.space * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            TerminalText(
              '> ',
              role: role,
            ),
            Expanded(
              child: TerminalText(
                widget.label,
                role: role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
