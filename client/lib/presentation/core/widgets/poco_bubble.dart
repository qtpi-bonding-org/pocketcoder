import 'package:flutter/material.dart';
import '../../../design_system/primitives/app_fonts.dart';
import '../../../design_system/primitives/app_palette.dart';
import '../../../design_system/primitives/app_sizes.dart';
import '../../../design_system/primitives/spacers.dart';
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
            color: Colors.black,
            border: Border.all(color: AppPalette.primary.primaryColor),
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
                        color: AppPalette.primary.textPrimary
                            .withValues(alpha: 0.5),
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
                  color: AppPalette.primary.textPrimary,
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
