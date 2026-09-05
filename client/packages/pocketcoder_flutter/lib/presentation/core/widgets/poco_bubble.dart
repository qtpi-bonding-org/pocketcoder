import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
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
  final PocoPosture posture;
  final PocoMood? mood;

  const PocoBubble({
    super.key,
    required this.message,
    required this.posture,
    this.mood,
    this.sequence = const [],
    this.history = const [],
    this.pocoSize,
    this.textAlign = TextAlign.start,
    this.showFace = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
                    height: (pocoSize ?? AppSizes.fontPoco) * 2,
                    child: Align(
                      alignment: Alignment.center,
                      child: PocoFace(
                        key: ValueKey(sequence),
                        fontSize: pocoSize ?? AppSizes.fontPoco,
                        sequence: sequence,
                        posture: posture,
                        mood: mood,
                      ),
                    ),
                  ),
                  VSpace.x1,
                ],
                Column(
                  crossAxisAlignment: crossAxisAlignment(textAlign),
                  children: [
                    ...history.map((msg) => Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.line),
                          child: Text(msg,
                              style: TextRole.label.style.copyWith(
                                fontFamily: AppFonts.family,
                                package: 'pocketcoder_flutter',
                              ),
                              textAlign: textAlign),
                        )),
                    TypewriterText(
                      key: ValueKey(message),
                      text: message,
                      style: TextRole.body.style.copyWith(
                        fontFamily: AppFonts.family,
                        package: 'pocketcoder_flutter',
                      ),
                      speed: const Duration(milliseconds: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  CrossAxisAlignment crossAxisAlignment(TextAlign textAlign) =>
      switch (textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.right => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      };
}

class PocoFace extends StatelessWidget {
  const PocoFace({
    super.key,
    this.fontSize,
    this.color,
    this.mood,
    this.posture = PocoPosture.armored,
    this.sequence = const [],
  });

  final double? fontSize;
  final Color? color;
  final PocoMood? mood;
  final PocoPosture posture;
  final List<(String, int)> sequence;

  @override
  Widget build(BuildContext context) => PocoAnimator(
        fontSize: fontSize,
        color: color,
        mood: mood,
        posture: posture,
        sequence: sequence,
      );
}
