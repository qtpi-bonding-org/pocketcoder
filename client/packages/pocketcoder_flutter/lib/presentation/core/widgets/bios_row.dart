import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// The trailing affordance a BiosRow renders. One row shape, four trailing
/// behaviors. `expand` covers two different reveal mechanics (opens a picker
/// dialog, or expands an inline accordion body) that share the same glyph;
/// BiosRow only renders `[v]`/`[^]` off the caller-owned `isExpanded` flag,
/// it never flips it itself -- the caller decides what "expand" means.
enum BiosRowVariant { row, toggle, input, expand }

class BiosRow extends StatelessWidget {
  const BiosRow({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.isSelected = false,
    this.isDestructive = false,
    this.isWarning = false,
    this.hasBadge = false,
    this.variant = BiosRowVariant.row,
    this.toggleValue = false,
    this.onToggleChanged,
    this.inputController,
    this.onInputChanged,
    this.inputHint,
    this.isExpanded = false,
    this.labelFontSize,
  });

  final String label;
  final String? value;

  /// Also sizes the `expand` variant's value text -- they share one row.
  final double? labelFontSize;

  /// Nullable -- a `row`-variant instance with no `onTap` renders as a
  /// static, non-interactive label/value pair (no InkWell, no chevron even
  /// when value is null). Needed by pocketcoder_pro's review-screen rows,
  /// which display data but never navigate/act on tap.
  final VoidCallback? onTap;
  final bool isSelected;

  /// Unrecoverable action (deletes local state/keys) -- red.
  final bool isDestructive;

  /// Recoverable but attention-worthy action (e.g. a session sign-out that
  /// doesn't delete anything) -- amber, distinct from [isDestructive]'s red.
  final bool isWarning;

  final bool hasBadge;
  final BiosRowVariant variant;

  final bool toggleValue;
  final ValueChanged<bool>? onToggleChanged;

  final TextEditingController? inputController;
  final ValueChanged<String>? onInputChanged;
  final String? inputHint;

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final textColor = isSelected
        ? colors.surface
        : (isDestructive
            ? terminalColors.danger
            : (isWarning ? terminalColors.warning : colors.onSurface));
    final bgColor = isSelected ? colors.onSurface : Colors.transparent;

    // Only variable-width trailing content (a value string, a TextField)
    // needs a flex share; fixed-size content (a chevron, a Switch) doesn't.
    final trailingNeedsFlex = variant == BiosRowVariant.input ||
        ((variant == BiosRowVariant.row || variant == BiosRowVariant.expand) &&
            value != null);
    final trailing = _trailing(context, textColor);

    final row = Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: textColor,
                      fontSize: labelFontSize ?? AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                      package: 'pocketcoder_flutter',
                    ),
                  ),
                ),
                if (hasBadge) ...[
                  HSpace.x1,
                  Text(
                    '[!]',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color:
                          isSelected ? colors.surface : terminalColors.warning,
                      fontSize: AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                ],
              ],
            ),
          ),
          HSpace.x2,
          trailingNeedsFlex ? Flexible(child: trailing) : trailing,
        ],
      ),
    );

    if (variant == BiosRowVariant.toggle || variant == BiosRowVariant.input) {
      // Trailing slot owns its own gesture surface (Switch/TextField) --
      // wrapping the whole row in an outer InkWell would fight it for taps.
      return row;
    }
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  Widget _trailing(BuildContext context, Color textColor) {
    switch (variant) {
      case BiosRowVariant.toggle:
        return Align(
          alignment: Alignment.centerRight,
          child: Switch(value: toggleValue, onChanged: onToggleChanged),
        );
      case BiosRowVariant.input:
        return TextField(
          controller: inputController,
          onChanged: onInputChanged,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: textColor,
            fontSize: AppSizes.fontStandard,
            fontWeight: AppFonts.heavy,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: inputHint,
          ),
        );
      case BiosRowVariant.expand:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value case final resolvedValue?) ...[
              Expanded(
                child: Text(
                  resolvedValue.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor,
                    fontSize: labelFontSize ?? AppSizes.fontStandard,
                    fontWeight: AppFonts.heavy,
                    package: 'pocketcoder_flutter',
                  ),
                ),
              ),
              HSpace.x1,
            ],
            Text(
              isExpanded ? '[^]' : '[v]',
              textAlign: TextAlign.right,
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
            ),
          ],
        );
      case BiosRowVariant.row:
        if (value case final resolvedValue?) {
          return Text(
            resolvedValue.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: textColor,
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
              package: 'pocketcoder_flutter',
            ),
          );
        }
        if (onTap == null) return const SizedBox.shrink();
        return Text(
          '[>]',
          textAlign: TextAlign.right,
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
        );
    }
  }
}
