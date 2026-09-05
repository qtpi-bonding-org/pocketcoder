import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// A 3-slot wizard footer layout that keeps the counter centered
/// regardless of whether back/next buttons are present.
///
/// Uses a Stack of three Aligns to achieve true centering even when one
/// or both of the flanking buttons are absent. A Row with spaceBetween
/// cannot do this — the centre item is only centred when the flanking
/// items are the same width.
class WizardFooterBar extends StatelessWidget {
  const WizardFooterBar({
    super.key,
    this.step,
    this.totalSteps,
    this.onBack,
    this.onNext,
  });

  final int? step;
  final int? totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final step = this.step;
    final totalSteps = this.totalSteps;
    final counterText =
        step != null && totalSteps != null ? '($step/$totalSteps)' : null;

    return Container(
      width: double.infinity,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Stack(
            children: [
              if (onBack case final back?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: BiosActionButton(
                    action: BiosActionStripItem(
                      label: 'back',
                      onTap: back,
                      bracketed: false,
                    ),
                  ),
                ),
              if (counterText case final text?)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                    child: TerminalText(
                      text,
                      role: TextRole.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (onNext case final next?)
                Align(
                  alignment: Alignment.centerRight,
                  child: BiosActionButton(
                    action: BiosActionStripItem(
                      label: 'next',
                      onTap: next,
                      bracketed: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
