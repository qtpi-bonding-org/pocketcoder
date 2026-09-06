import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class GlyphLabelRow extends StatelessWidget {
  const GlyphLabelRow({
    super.key,
    required this.glyph,
    required this.child,
    this.spacing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String glyph;
  final Widget child;
  final SizedBox? spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          TerminalText(glyph, role: TextRole.label),
          spacing ?? HSpace.x1,
          Expanded(child: child),
        ],
      );
}
