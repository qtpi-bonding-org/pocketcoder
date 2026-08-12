import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// Progressive disclosure for one marked provisioning concept.
///
/// The parent owns [expanded] so the widget stays a pure view and can be
/// adapted to a Cubit without giving the widget access to application state.
class WalkthroughSnippet extends StatelessWidget {
  const WalkthroughSnippet({
    super.key,
    required this.previewCode,
    required this.expandedCode,
    required this.sourceLabel,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final String previewCode;
  final String expandedCode;
  final String sourceLabel;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final code = expanded ? expandedCode : previewCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CodeSurface(
          code: code,
          maxHeight: expanded
              ? AppSizes.provisioningSnippetMaxHeight
              : AppSizes.provisioningSnippetPreviewMaxHeight,
          sourceLabel: sourceLabel,
        ),
        VSpace.x1,
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            toggled: expanded,
            label: expanded
                ? context.l10n.pocoProvisioningShowConcise
                : context.l10n.pocoProvisioningShowFull,
            child: TextButton.icon(
              onPressed: () => onExpandedChanged(!expanded),
              icon: Icon(
                expanded ? Icons.unfold_less : Icons.unfold_more,
                size: AppSizes.iconSmall,
              ),
              label: Text(
                expanded
                    ? context.l10n.pocoProvisioningShowConcise
                    : context.l10n.pocoProvisioningShowFull,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeSurface extends StatelessWidget {
  const _CodeSurface({
    required this.code,
    required this.maxHeight,
    required this.sourceLabel,
  });

  final String code;
  final double maxHeight;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText.tiny(sourceLabel, alpha: 0.6),
          VSpace.x1,
          Divider(
            height: AppSizes.borderWidth,
            color: colors.primary.withValues(alpha: 0.2),
          ),
          VSpace.x1,
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
