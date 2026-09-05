import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class TerminalProgressBar extends StatelessWidget {
  const TerminalProgressBar({
    super.key,
    required this.step,
    required this.total,
    this.width = 8,
    this.role = TextRole.body,
  }) : assert(width > 0, 'a zero-width bar renders nothing');

  static const String filledGlyph = '█';
  static const String emptyGlyph = '░';

  final int step;

  /// A non-positive total renders empty rather than dividing by zero -- a
  /// phase can report its step count later than its first frame.
  final int total;

  final int width;

  final TextRole role;

  int get filled {
    if (total <= 0) return 0;
    final clamped = step.clamp(0, total);
    final cells = (clamped / total * width).round();
    // A full bar claims the phase is finished, so rounding up to `width`
    // while steps remain would report completion early.
    if (clamped < total && cells >= width) return width - 1;
    return cells;
  }

  @override
  Widget build(BuildContext context) => TerminalText(
        filledGlyph * filled + emptyGlyph * (width - filled),
        role: role,
      );
}
