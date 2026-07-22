// Renders one tool invocation card. Wired to Builders.customMessageBuilder
// for metadata['kind'] == 'toolCall'. Lifted from chat_screen.dart's old
// _ToolCallCard — same terminal styling, now reading name/args/result off
// CustomMessage.metadata instead of the old ToolCall domain type.
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ToolCallCard extends StatelessWidget {
  final chat_core.CustomMessage message;

  const ToolCallCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final name = (message.metadata?['name'] as String?) ?? '';
    final args = (message.metadata?['args'] as String?) ?? '';
    final result = message.metadata?['result'] as String?;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.space,
        vertical: AppSizes.space * 0.5,
      ),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.04),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                size: 14,
                color: terminalColors.attention,
              ),
              HSpace.x1,
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: terminalColors.attention,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          if (args.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'ARGS: $args',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (result != null) ...[
            VSpace.x1,
            Text(
              'RESULT: $result',
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
