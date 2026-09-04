import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'poco_animator.dart';
import 'typewriter_text.dart';

class PocoBubble extends StatelessWidget {
  final String message;
  final List<(String, int)> sequence;
  final List<String> history;
  final double? pocoSize;
  final TextAlign textAlign;
  final bool showFace;

  const PocoBubble({
    super.key,
    required this.message,
    this.sequence = const [],
    this.history = const [],
    this.pocoSize,
    this.textAlign = TextAlign.start,
    this.showFace = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, AppSizes.contentMaxWidth)
            : AppSizes.contentMaxWidth;
        return SizedBox(
          width: double.infinity,
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: bubbleWidth.toDouble(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showFace) ...[
                    SizedBox(
                      height: (pocoSize ?? AppSizes.fontBody) * 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: PocoFace(
                          key: ValueKey(sequence),
                          fontSize: pocoSize ?? AppSizes.fontBody,
                          sequence: sequence,
                        ),
                      ),
                    ),
                    VSpace.x4,
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: Container(
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
                                    fontFamily: AppFonts.family,
                                    package: 'pocketcoder_flutter',
                                    color:
                                        colors.onSurface.withValues(alpha: 0.5),
                                  ),
                                  textAlign: textAlign,
                                ),
                              )),
                          TypewriterText(
                            key: ValueKey(message),
                            text: message,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              package: 'pocketcoder_flutter',
                              color: colors.onSurface,
                            ),
                            speed: const Duration(milliseconds: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

/// Poco's animated face, separated from the message surface so a
/// multi-turn conversation can show one face and several replies.
class PocoFace extends StatelessWidget {
  const PocoFace({
    super.key,
    this.fontSize,
    this.color,
    this.sequence = const [],
  });

  final double? fontSize;
  final Color? color;
  final List<(String, int)> sequence;

  @override
  Widget build(BuildContext context) => PocoAnimator(
        fontSize: fontSize,
        color: color,
        sequence: sequence,
      );
}
