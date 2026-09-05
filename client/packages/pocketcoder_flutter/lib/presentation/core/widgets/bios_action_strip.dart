import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// A single bracket-style action -- pulled out of TerminalFooter's
/// TerminalAction/_buildActionButton so other action rows and TerminalFooter
/// share one invert-on-active mechanic instead of each reinventing it.
class BiosActionStripItem {
  const BiosActionStripItem({
    required this.label,
    required this.onTap,
    this.kind = ActionKind.neutral,
    this.isActive = false,
    this.hasBadge = false,
    this.bracketed = true,
  });

  final String label;
  final VoidCallback onTap;
  final ActionKind kind;

  /// The currently-selected tab/choice -- reverse video, permanently, not
  /// just while pressed. Orthogonal to [kind]: a selected tab can still be
  /// any semantic kind.
  final bool isActive;

  final bool hasBadge;

  /// false: plain label (nav footer needs no brackets for space). true: bracketed.
  final bool bracketed;
}

/// A bare row of [BiosActionStripItem] buttons -- no outer border/SafeArea
/// chrome, unlike TerminalFooter (which wraps the same button mechanic in
/// full-bleed page-footer chrome). Meant to sit inside a card's footer
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
class BiosActionButton extends StatefulWidget {
  const BiosActionButton({super.key, required this.action});

  final BiosActionStripItem action;

  @override
  State<BiosActionButton> createState() => _BiosActionButtonState();
}

class _BiosActionButtonState extends State<BiosActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final role = action.kind.role;
    final reversed = action.isActive || _pressed;

    Widget text(String text, TextRole role, {int? maxLines}) {
      final rendered = TerminalText(
        text,
        role: role,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
      if (!reversed) return rendered;
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(AppPalette.ground, BlendMode.srcIn),
        child: rendered,
      );
    }

    final displayLabel = action.bracketed
        ? '<${action.label}>'
        : action.label;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: action.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        color: reversed ? role.color : Colors.transparent,
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space, vertical: AppSizes.space * 1.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: text(displayLabel, role, maxLines: 1),
            ),
            if (action.hasBadge) ...[
              HSpace.x1,
              text('[!]', TextRole.warn),
            ],
          ],
        ),
      ),
    );
  }
}
