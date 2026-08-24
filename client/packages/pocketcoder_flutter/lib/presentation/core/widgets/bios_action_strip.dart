import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A single bracket-style action -- pulled out of TerminalFooter's
/// TerminalAction/_buildActionButton so BiosCard footers and TerminalFooter
/// share one invert-on-active mechanic instead of each reinventing it (see
/// the color-system spec section 3.1/5.1: this IS that mechanic, just no
/// longer only reachable through TerminalFooter).
class BiosActionStripItem {
  const BiosActionStripItem({
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.hasBadge = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool hasBadge;
  final Color? color;
}

/// A bare row of [BiosActionStripItem] buttons -- no outer border/SafeArea
/// chrome, unlike TerminalFooter (which wraps the same button mechanic in
/// full-bleed page-footer chrome). Meant to sit inside a BiosCard's footer
/// slot, or standalone wherever a screen needs a row of actions under some
/// content that isn't a whole-page footer.
class BiosActionStrip extends StatelessWidget {
  const BiosActionStrip({super.key, required this.actions});

  final List<BiosActionStripItem> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          Expanded(child: BiosActionButton(action: action)),
      ],
    );
  }
}

/// The single-button renderer shared by [BiosActionStrip] and
/// [TerminalFooter] -- an extraction of TerminalFooter's former
/// _buildActionButton body, unchanged in behavior, just no longer private
/// to that one widget.
class BiosActionButton extends StatelessWidget {
  const BiosActionButton({super.key, required this.action});

  final BiosActionStripItem action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final resolved = selectable(
      action.color ?? colors.onSurface,
      selected: action.isActive,
    );
    final bgColor = resolved.fill ?? Colors.transparent;
    final fgColor = resolved.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        splashColor: colors.onSurface.withValues(alpha: 0.2),
        highlightColor: colors.onSurface.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
          decoration: BoxDecoration(color: bgColor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action.label.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: fgColor,
                  fontSize: AppSizes.fontMini,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
              if (action.hasBadge) ...[
                HSpace.x1,
                Text(
                  '[!]',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: action.isActive
                        ? Colors.black
                        : terminalColors.warning,
                    fontSize: AppSizes.fontMini,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
