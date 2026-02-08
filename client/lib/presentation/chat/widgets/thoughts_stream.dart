import 'package:flutter/material.dart';
import '../../../../design_system/primitives/app_fonts.dart';
import '../../../../design_system/primitives/app_palette.dart';
import '../../../../design_system/primitives/app_sizes.dart';
import '../../../../domain/chat/chat_message.dart';

class ThoughtsStream extends StatelessWidget {
  final List<MessagePart> parts;

  const ThoughtsStream({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return Center(
        child: Text(
          '[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]',
          style: TextStyle(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontTiny,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: parts.length,
      reverse: true, // Auto-scroll to bottom of thoughts
      itemBuilder: (context, index) {
        // Reverse index for 'reverse: true'
        final part = parts[parts.length - 1 - index];
        return _buildPart(context, part);
      },
    );
  }

  Widget _buildPart(BuildContext context, MessagePart part) {
    return part.map(
      text: (textPart) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '> ${textPart.text}',
            style: TextStyle(
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.6),
              fontFamily: AppFonts.headerFamily,
              fontSize: 10,
            ),
          ),
        );
      },
      toolCall: (toolPart) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
                left: BorderSide(
                    color: AppPalette.primary.primaryColor, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXEC: ${toolPart.tool.toUpperCase()}',
                style: TextStyle(
                  color: AppPalette.primary.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              if (toolPart.args != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    toolPart.args.toString(),
                    style: TextStyle(
                      color:
                          AppPalette.primary.textPrimary.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
      toolResult: (resultPart) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          'RESULT [${resultPart.tool}]: ${resultPart.content ?? "No content"}',
          style: TextStyle(
            color: (resultPart.isError ?? false) ? Colors.red : Colors.green,
            fontSize: 9,
          ),
        ),
      ),
      stepStart: (startPart) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Divider(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.1),
            height: 1),
      ),
      stepFinish: (finishPart) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          'STEP COMPLETE (${finishPart.reason})',
          style: TextStyle(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
