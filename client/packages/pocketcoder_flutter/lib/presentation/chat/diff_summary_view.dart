import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'diff_stats.dart';

const int kDiffLineCap = 300;

class DiffSummaryLine extends StatefulWidget {
  const DiffSummaryLine({
    super.key,
    required this.path,
    required this.oldText,
    required this.newText,
  });

  final String path;
  final String oldText;
  final String newText;

  @override
  State<DiffSummaryLine> createState() => _DiffSummaryLineState();
}

class _DiffSummaryLineState extends State<DiffSummaryLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final isNewFile = widget.oldText.isEmpty;
    final stats = computeDiffStats(widget.oldText, widget.newText);
    final label = isNewFile
        ? '${widget.path.toUpperCase()} (NEW FILE)'
        : '${widget.path.toUpperCase()} (+${stats.added} -${stats.removed})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              HSpace.x1,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontMini,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded) DiffBody(lines: stats.lines),
      ],
    );
  }
}

class DiffBody extends StatelessWidget {
  const DiffBody({super.key, required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final terminalColors = context.terminalColors;
    final colors = context.colorScheme;
    final capped = lines.length > kDiffLineCap ? lines.sublist(0, kDiffLineCap) : lines;
    final omitted = lines.length - capped.length;

    Color colorFor(DiffLineKind kind) => switch (kind) {
          DiffLineKind.added => terminalColors.attention,
          DiffLineKind.removed => terminalColors.danger,
          DiffLineKind.context => colors.onSurface.withValues(alpha: 0.7),
        };

    String prefixFor(DiffLineKind kind) => switch (kind) {
          DiffLineKind.added => '+ ',
          DiffLineKind.removed => '- ',
          DiffLineKind.context => '  ',
        };

    return Container(
      margin: EdgeInsets.only(top: AppSizes.space * 0.5),
      padding: EdgeInsets.all(AppSizes.space * 0.5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.15),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in capped)
            Text(
              '${prefixFor(line.kind)}${line.text}',
              style: TextStyle(
                color: colorFor(line.kind),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
          if (omitted > 0)
            Text(
              '… $omitted more lines omitted',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
        ],
      ),
    );
  }
}
