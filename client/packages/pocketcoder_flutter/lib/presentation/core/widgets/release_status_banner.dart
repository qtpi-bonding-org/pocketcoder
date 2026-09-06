import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class ReleaseStatusScope extends InheritedWidget {
  const ReleaseStatusScope({
    super.key,
    required this.state,
    required this.onDismiss,
    required super.child,
  });

  final ReleaseStatusState state;
  final VoidCallback onDismiss;

  static ReleaseStatusScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReleaseStatusScope>();

  @override
  bool updateShouldNotify(ReleaseStatusScope oldWidget) =>
      state != oldWidget.state;
}

class ReleaseStatusBanner extends StatelessWidget {
  const ReleaseStatusBanner({
    super.key,
    required this.state,
    required this.onDismiss,
  });

  final ReleaseStatusState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    if (!state.shouldShowNotice || snapshot == null) {
      return const SizedBox.shrink();
    }
    final critical =
        snapshot.status == ServerReleaseStatus.criticalReleaseWarning;
    final color =
        critical ? context.terminalColors.warning : context.colorScheme.primary;
    final label = critical
        ? context.l10n.pocketCoderUpdateCriticalStatus
        : context.l10n.pocketCoderUpdateAvailableStatus;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space,
        vertical: AppSizes.space / 2,
      ),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              snapshot.summary == null ? label : '$label — ${snapshot.summary}',
              style: TextStyle(
                color: color,
                fontFamily: AppFonts.family,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ),
          if (!critical)
            TerminalButton(
              label: context.l10n.actionDismiss,
              kind: ActionKind.refusal,
              onTap: onDismiss,
            ),
        ],
      ),
    );
  }
}
