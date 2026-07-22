// Renders one completed text/reasoning turn (ChatMessageBubble, wired to
// Builders.textMessageBuilder) or one in-progress streaming turn
// (ChatStreamMessageBubble, wired to Builders.textStreamMessageBuilder).
// Lifted from chat_screen.dart's old _ChatMessageTile — same terminal
// COMMANDER/POCO/THINKING styling, now driven by flutter_chat_core's
// TextMessage/TextStreamMessage + a StreamState instead of the old
// ChatMessage domain type.
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'timeline_to_messages.dart';

class ChatMessageBubble extends StatelessWidget {
  final chat_core.TextMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isReasoning = message.metadata?['kind'] == 'reasoning';
    return _Bubble(
      isUser: message.authorId == kUserAuthorId,
      isReasoning: isReasoning,
      child: Text(
        message.text,
        style: TextStyle(
          color: isReasoning
              ? context.colorScheme.onSurface.withValues(alpha: 0.7)
              : context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          fontStyle: isReasoning ? FontStyle.italic : FontStyle.normal,
          height: 1.4,
        ),
      ),
    );
  }
}

class ChatStreamMessageBubble extends StatelessWidget {
  final chat_core.TextStreamMessage message;
  final int index;
  final StreamState streamState;

  const ChatStreamMessageBubble({
    super.key,
    required this.message,
    required this.index,
    required this.streamState,
  });

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      isUser: message.authorId == kUserAuthorId,
      isReasoning: false,
      child: FlyerChatTextStreamMessage(
        message: message,
        index: index,
        streamState: streamState,
        padding: EdgeInsets.zero,
        showTime: false,
        showStatus: false,
        sentTextStyle: TextStyle(
          color: context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          height: 1.4,
        ),
        receivedTextStyle: TextStyle(
          color: context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final bool isReasoning;
  final Widget child;

  const _Bubble({required this.isUser, required this.isReasoning, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final accent = isReasoning
        ? terminalColors.warning
        : isUser
            ? terminalColors.user
            : colors.primary;
    final label = isUser ? 'COMMANDER' : (isReasoning ? 'THINKING' : 'POCO');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.06),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                size: 14,
                color: accent,
              ),
              HSpace.x1,
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          VSpace.x1,
          child,
        ],
      ),
    );
  }
}
