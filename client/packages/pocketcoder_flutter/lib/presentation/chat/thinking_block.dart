// ThinkingBlock renders one reasoning entry in the chat timeline as a
// terminal-style status row with expandable text. It opens automatically
// only while it is the newest reasoning entry; older entries collapse when a
// newer one arrives. Tapping the status row always toggles it.
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

class ThinkingBlock extends StatefulWidget {
  final String text;
  final bool isLatest;
  final bool isStreaming;

  const ThinkingBlock({
    super.key,
    required this.text,
    required this.isLatest,
    required this.isStreaming,
  });

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  late bool _expanded = widget.isLatest;

  @override
  void didUpdateWidget(covariant ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLatest != oldWidget.isLatest) {
      _expanded = widget.isLatest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
            child: Row(
              children: [
                Text(
                  _expanded ? '▾' : '▸',
                  style: TextStyle(
                    color: terminalColors.warning,
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontSmall,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                HSpace.x1,
                TerminalStatusGlyph(
                  status: widget.isStreaming
                      ? TerminalStatus.running
                      : TerminalStatus.success,
                  fontSize: AppSizes.fontSmall,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: Text(
              widget.text,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
