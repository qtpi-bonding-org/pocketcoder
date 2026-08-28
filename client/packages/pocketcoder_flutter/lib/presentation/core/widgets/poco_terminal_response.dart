import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/typewriter_text.dart';

/// A Poco response for the terminal-style conversation chat.
///
/// The avatar is intentionally not part of this widget. [ChatView] places one
/// centered avatar above the transcript; this widget owns only the reusable
/// terminal response line and its typewriter animation.
class PocoTerminalResponse extends StatelessWidget {
  const PocoTerminalResponse({
    super.key,
    required this.messageId,
    required this.message,
    required this.instant,
    this.onAnimationComplete,
    this.speed = const Duration(milliseconds: 10),
  });

  final String messageId;
  final String message;
  final bool instant;
  final VoidCallback? onAnimationComplete;
  final Duration speed;

  @override
  Widget build(BuildContext context) {
    return TerminalConversationFrame(
      speaker: TerminalConversationSpeaker.poco,
      child: TerminalTranscriptLine(
        prefix: '[poco] ',
        color: context.colorScheme.primary,
        child: TypewriterText(
          key: ValueKey(messageId),
          text: message,
          speed: speed,
          instant: instant,
          onComplete: onAnimationComplete,
          style: TextStyle(
            color: context.colorScheme.primary,
            fontFamily: AppFonts.bodyFamily,
            package: 'pocketcoder_flutter',
            fontSize: AppSizes.fontStandard,
            fontWeight: AppFonts.medium,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
