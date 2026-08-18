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
    required this.message,
    this.speed = const Duration(milliseconds: 10),
  });

  final String message;
  final Duration speed;

  @override
  Widget build(BuildContext context) {
    return TerminalConversationFrame(
      speaker: TerminalConversationSpeaker.poco,
      child: TerminalTranscriptLine(
        prefix: '[poco] ',
        color: context.colorScheme.primary,
        child: TypewriterText(
          text: message,
          speed: speed,
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
