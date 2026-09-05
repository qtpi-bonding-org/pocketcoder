import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';

class TerminalButton extends StatefulWidget {
  const TerminalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = ActionKind.neutral,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final ActionKind kind;
  final bool isLoading;

  @override
  State<TerminalButton> createState() => _TerminalButtonState();
}

class _TerminalButtonState extends State<TerminalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.kind.role;

    final label = TerminalText('<${widget.label.toLowerCase()}>', role: role);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          const TerminalSpinner(),
          HSpace.x2,
        ],
        Flexible(
          child: _pressed
              ? ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                      AppPalette.ground, BlendMode.srcIn),
                  child: label,
                )
              : label,
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        color: _pressed ? role.color : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2,
          vertical: AppSizes.space,
        ),
        child: content,
      ),
    );
  }
}
