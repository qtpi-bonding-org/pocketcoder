import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ProvisioningLessonCodeBlock {
  const ProvisioningLessonCodeBlock({
    required this.title,
    required this.sourceLabel,
    required this.code,
  });

  final String title;
  final String sourceLabel;
  final String code;
}

/// A single provisioning lesson: one important excerpt by default, with every
/// complete source block available on demand.
class ProvisioningLessonCard extends StatelessWidget {
  const ProvisioningLessonCard({
    super.key,
    required this.title,
    required this.explanation,
    required this.importantCode,
    required this.codeBlocks,
    required this.lessonNumber,
    required this.lessonCount,
    required this.expanded,
    required this.onExpandedChanged,
    this.onPrevious,
    this.onNext,
  });

  final String title;
  final String explanation;
  final String importantCode;
  final List<ProvisioningLessonCodeBlock> codeBlocks;
  final int lessonNumber;
  final int lessonCount;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final blocks = codeBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PocoBubble(
          message: explanation,
          sequence: PocoExpressions.thinking,
          pocoSize: AppSizes.fontLarge,
        ),
        VSpace.x3,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TerminalText(
                title.toUpperCase(),
                weight: TerminalTextWeight.heavy,
              ),
            ),
            HSpace.x2,
            TerminalText.tiny(
              '$lessonNumber / $lessonCount',
              alpha: 0.6,
            ),
          ],
        ),
        VSpace.x2,
        if (expanded)
          for (var index = 0; index < blocks.length; index += 1) ...[
            _CodeBlockView(
              block: blocks[index],
              partNumber: index + 1,
              partCount: blocks.length,
              maxHeight: 320,
            ),
            if (index < blocks.length - 1) VSpace.x2,
          ]
        else
          _ImportantCodeView(
            code: importantCode,
            sourceLabel: blocks.isEmpty ? null : blocks.first.sourceLabel,
          ),
        VSpace.x2,
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSizes.space,
          runSpacing: AppSizes.space,
          children: [
            TextButton(
              onPressed: onPrevious,
              child: Text(context.l10n.pocoProvisioningPrevious),
            ),
            TextButton.icon(
              onPressed:
                  blocks.isEmpty ? null : () => onExpandedChanged(!expanded),
              icon: Icon(
                expanded ? Icons.unfold_less : Icons.unfold_more,
                size: AppSizes.fontStandard,
              ),
              label: Text(
                expanded
                    ? context.l10n.pocoProvisioningShowConcise
                    : '${context.l10n.pocoProvisioningShowFull} (${blocks.length})',
              ),
            ),
            TextButton(
              onPressed: onNext,
              child: Text(context.l10n.pocoProvisioningNext),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImportantCodeView extends StatelessWidget {
  const _ImportantCodeView({
    required this.code,
    required this.sourceLabel,
  });

  final String code;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    return _CodeSurface(
      code: code,
      maxHeight: 220,
      header: sourceLabel == null
          ? null
          : TerminalText.tiny(sourceLabel ?? '', alpha: 0.55),
    );
  }
}

class _CodeBlockView extends StatelessWidget {
  const _CodeBlockView({
    required this.block,
    required this.partNumber,
    required this.partCount,
    required this.maxHeight,
  });

  final ProvisioningLessonCodeBlock block;
  final int partNumber;
  final int partCount;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return _CodeSurface(
      code: block.code,
      maxHeight: maxHeight,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TerminalText.label(
                  block.title.toUpperCase(),
                ),
                TerminalText.tiny(block.sourceLabel, alpha: 0.55),
              ],
            ),
          ),
          HSpace.x2,
          TerminalText.tiny('$partNumber / $partCount', alpha: 0.55),
        ],
      ),
    );
  }
}

class _CodeSurface extends StatelessWidget {
  const _CodeSurface({
    required this.code,
    required this.maxHeight,
    required this.header,
  });

  final String code;
  final double maxHeight;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final currentHeader = header;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currentHeader != null) ...[
            currentHeader,
            VSpace.x1,
            Divider(
              height: AppSizes.borderWidth,
              color: colors.primary.withValues(alpha: 0.2),
            ),
            VSpace.x1,
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface,
                    fontSize: AppSizes.fontTiny,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
