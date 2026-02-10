import 'package:flutter/material.dart';
import '../../../../design_system/primitives/app_fonts.dart';
import '../../../../design_system/primitives/app_palette.dart';
import '../../../../design_system/primitives/app_sizes.dart';
import '../../../../design_system/primitives/spacers.dart';
import '../../../../domain/chat/chat_message.dart';

class SpeechBubble extends StatelessWidget {
  final List<MessagePartText> textParts;
  final bool isUser;

  const SpeechBubble({
    super.key,
    required this.textParts,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (textParts.isEmpty) return const SizedBox.shrink();

    // Consolidate text for now
    final fullText = textParts.map((e) => e.text ?? '').join('\n');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: isUser
            ? AppPalette.primary.primaryColor.withValues(alpha: 0.1)
            : AppPalette.primary.backgroundPrimary.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.2),
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
                color: AppPalette.primary.textPrimary.withValues(alpha: 0.5),
              ),
              HSpace.x1,
              Text(
                isUser ? 'OPERATOR' : 'POCO',
                style: TextStyle(
                  color: AppPalette.primary.textPrimary.withValues(alpha: 0.5),
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
              color: AppPalette.primary.textPrimary,
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
