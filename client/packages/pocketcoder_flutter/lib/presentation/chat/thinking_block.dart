import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/status_marker_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';

class ThinkingBlock extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const ThinkingBlock({
    super.key,
    required this.text,
    required this.isStreaming,
  });

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '[ THOUGHTS ]',
                  style: TextStyle(
                    color: colors.primary,
                    fontFamily: AppFonts.family,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                HSpace.x1,
                widget.isStreaming
                    ? const TerminalSpinner()
                    : const StatusMarkerView(marker: StatusMarker.ok),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
            child: Text(
              widget.text,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.family,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
