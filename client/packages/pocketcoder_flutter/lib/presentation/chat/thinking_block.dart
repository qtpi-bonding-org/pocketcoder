// ThinkingBlock: renders one reasoning ("thinking") entry in the chat
// timeline as a collapsible pill followed by a small Poco avatar --
// collapsed by default, expanded automatically only while it's the newest
// reasoning entry in the conversation (still streaming or just finished).
// Older ones collapse the moment a newer one arrives, mirroring how
// Claude's own app keeps only the latest "Thought for Xs" open. Tapping the
// header always toggles it regardless of "latest" status.
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_animator.dart';

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
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: terminalColors.warning,
                ),
                Icon(Icons.smart_toy_outlined,
                    size: 14, color: terminalColors.warning),
                HSpace.x1,
                Text(
                  widget.isStreaming
                      ? context.l10n.chatThinkingLive
                      : context.l10n.chatThought,
                  style: TextStyle(
                    color: terminalColors.warning,
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
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
        Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space),
          child: PocoAnimator(
            fontSize: AppSizes.fontLarge,
            sequence: widget.isStreaming
                ? PocoExpressions.thinking
                : PocoExpressions.happy,
          ),
        ),
      ],
    );
  }
}
