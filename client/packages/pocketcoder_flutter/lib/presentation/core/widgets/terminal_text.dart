import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

/// A standardised text widget that renders text with semantic roles.
///
/// Roles define both color and weight; the theme supplies size.
/// This replaces ad-hoc `TextStyle(…)` patterns.
class TerminalText extends StatelessWidget {
  const TerminalText(
    this.text, {
    super.key,
    required this.role,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextRole role;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: role.style,
      );
}
