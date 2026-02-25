import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class SpeechBubble extends StatelessWidget {
  final List<dynamic> textParts;
  final bool isUser;
  const SpeechBubble({
    super.key,
    required this.textParts,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (textParts.isEmpty) return const SizedBox.shrink();

    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    // Consolidate text from parts
    final fullText = textParts.map((e) {
      if (e is Map<String, dynamic>) {
        return e['text'] ?? '';
      }
      return '';
    }).join('\n');

    if (fullText.trim().isEmpty) return const SizedBox.shrink();

    // Dynamic Label
    final String label = isUser ? 'USER' : 'POCO';
    final Color accentColor = isUser ? terminalColors.user : colors.onSurface;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: isUser
            ? terminalColors.user.withValues(alpha: 0.05)
            : colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.1),
            width: 1,
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
                size: 16,
                color: accentColor,
              ),
              HSpace.x1,
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          VSpace.x1,
          Text(
            fullText,
            style: TextStyle(
              color: isUser ? accentColor : context.textTheme.bodyLarge?.color,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
