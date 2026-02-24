import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';
import 'poco_animator.dart';
import 'typewriter_text.dart';

class PocoBubble extends StatelessWidget {
  final String message;
  final List<(String, int)> sequence;
  final List<String> history;
  final double? pocoSize;
  final TextAlign textAlign;

  const PocoBubble({
    super.key,
    required this.message,
    this.sequence = const [],
    this.history = const [],
    this.pocoSize,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PocoAnimator(
          key: ValueKey(sequence),
          fontSize: pocoSize ?? AppSizes.fontLarge,
          sequence: sequence,
        ),
        VSpace.x4,
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space * 2,
            vertical: AppSizes.space,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.primary),
          ),
          child: Column(
            crossAxisAlignment: crossAxisAlignment(textAlign),
            children: [
              ...history.map((msg) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      msg,
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        package: 'pocketcoder_flutter',
                        color: colors.onSurface.withValues(alpha: 0.5),
                        fontSize: AppSizes.fontStandard,
                      ),
                      textAlign: textAlign,
                    ),
                  )),
              TypewriterText(
                key: ValueKey(message),
                text: message,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  package: 'pocketcoder_flutter',
                  color: colors.onSurface,
                  fontSize: AppSizes.fontStandard,
                ),
                speed: const Duration(milliseconds: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  CrossAxisAlignment crossAxisAlignment(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }
}
