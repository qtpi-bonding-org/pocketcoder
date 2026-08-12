import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

enum PocketCoderProgressPhaseState {
  waiting,
  running,
  complete,
  failed,
}

class PocketCoderProgressPhase {
  const PocketCoderProgressPhase({
    required this.label,
    required this.progress,
    required this.currentStep,
    required this.state,
    this.progressText,
  });

  final String label;
  final double progress;
  final String currentStep;
  final PocketCoderProgressPhaseState state;
  final String? progressText;
}

/// Compact CLI-style status pane for the two real PocketCoder phases.
///
/// This is presentation-only. The adapter maps deployment state into the two
/// [PocketCoderProgressPhase] values and supplies them here.
class PocketCoderProgressPane extends StatelessWidget {
  const PocketCoderProgressPane({
    super.key,
    required this.provision,
    required this.deploy,
  });

  final PocketCoderProgressPhase provision;
  final PocketCoderProgressPhase deploy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: colors.primary.withValues(alpha: 0.35),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PocketCoderProgressPhaseView(phase: provision),
          VSpace.x2,
          Divider(
            height: AppSizes.borderWidth,
            color: colors.primary.withValues(alpha: 0.2),
          ),
          VSpace.x2,
          _PocketCoderProgressPhaseView(phase: deploy),
        ],
      ),
    );
  }
}

class _PocketCoderProgressPhaseView extends StatelessWidget {
  const _PocketCoderProgressPhaseView({required this.phase});

  final PocketCoderProgressPhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final phaseColor = switch (phase.state) {
      PocketCoderProgressPhaseState.waiting =>
        colors.onSurface.withValues(alpha: 0.45),
      PocketCoderProgressPhaseState.running => colors.primary,
      PocketCoderProgressPhaseState.complete => terminalColors.attention,
      PocketCoderProgressPhaseState.failed => terminalColors.danger,
    };
    final progress = phase.progress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _PocketCoderProgressStatusGlyph(state: phase.state),
            HSpace.x1,
            Expanded(
              child: TerminalText(
                phase.label.toUpperCase(),
                color: phaseColor,
                weight: TerminalTextWeight.heavy,
              ),
            ),
            TerminalText.tiny(
              phase.progressText ?? '${(progress * 100).round()}%',
              alpha: phase.state == PocketCoderProgressPhaseState.waiting
                  ? 0.45
                  : 0.8,
            ),
          ],
        ),
        VSpace.x1,
        LinearProgressIndicator(
          value: progress,
          minHeight: AppSizes.progressBarHeight,
          color: phaseColor,
          backgroundColor: phaseColor.withValues(alpha: 0.12),
        ),
        VSpace.x1,
        TerminalText.tiny(
          '\$ ${phase.currentStep.toUpperCase()}',
          color: phaseColor,
          alpha: 0.8,
        ),
      ],
    );
  }
}

class _PocketCoderProgressStatusGlyph extends StatelessWidget {
  const _PocketCoderProgressStatusGlyph({required this.state});

  final PocketCoderProgressPhaseState state;

  @override
  Widget build(BuildContext context) {
    if (state == PocketCoderProgressPhaseState.waiting) {
      return TerminalText.label(
        '-',
        color: context.colorScheme.onSurface,
        alpha: 0.45,
      );
    }

    return TerminalStatusGlyph(
      status: switch (state) {
        PocketCoderProgressPhaseState.running => TerminalStatus.running,
        PocketCoderProgressPhaseState.complete => TerminalStatus.success,
        PocketCoderProgressPhaseState.failed => TerminalStatus.failure,
        PocketCoderProgressPhaseState.waiting => TerminalStatus.attention,
      },
      fontSize: AppSizes.fontStandard,
    );
  }
}
