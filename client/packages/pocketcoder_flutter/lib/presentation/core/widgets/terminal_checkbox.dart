import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A `[ ]`/`[X]` glyph standing in for a boolean toggle, matching this
/// app's other terminal-style row affordances ([>], [^]/[v], [!]) instead
/// of a stock Material Switch/Checkbox.
class TerminalCheckbox extends StatelessWidget {
  const TerminalCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.color,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Text(
          value ? '[X]' : '[ ]',
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: color ?? context.colorScheme.onSurface,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ),
    );
  }
}
