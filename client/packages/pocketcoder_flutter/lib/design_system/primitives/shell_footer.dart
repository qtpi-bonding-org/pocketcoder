import 'package:flutter/foundation.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';

// Forward declare TerminalAction (defined in presentation/core/widgets/terminal_footer.dart)
final class TerminalAction {
  const TerminalAction({
    required this.label,
    required this.onTap,
    this.hasBadge = false,
    this.isActive = false,
    this.kind = ActionKind.neutral,
    this.isLabel = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool hasBadge;
  final bool isActive;
  final ActionKind kind;
  final bool isLabel;
}

/// A single action a dead-end footer can offer (e.g. "retry", "contact support").
final class ShellAction {
  const ShellAction(
      {required this.label, required this.kind, required this.onTap});
  final String label;
  final ActionKind kind;
  final VoidCallback onTap;
}

/// What the shell puts at the bottom of the screen.
///
/// Supplied by the route, never by the screen -- `harness_auth` and `deploy`
/// are each reachable from both a wizard flow and from inside the app, so a
/// screen-level property would be wrong in one of its two homes.
sealed class ShellFooter {
  const ShellFooter();
}

/// Inside the app. You are somewhere.
final class PillarFooter extends ShellFooter {
  const PillarFooter({
    required this.active,
    required this.onSelect,
    this.available = NavPillar.values,
    this.configureBadge = false,
    this.extraActions = const [],
  });
  final NavPillar active;
  final ValueChanged<NavPillar> onSelect;
  final List<NavPillar> available;
  final bool configureBadge;
  final List<TerminalAction> extraActions;
  // Deliberately carries no step position. A destination is not a step.
}

/// A linear flow: onboarding, provisioning, deployment, harness auth on the
/// onboarding path.
///
/// `step` and `totalSteps` are required. A wizard that cannot say where it is
/// has no business being a wizard, and the position is real data already held
/// by the flow's step list -- never a decorative fraction.
final class WizardFooter extends ShellFooter {
  const WizardFooter({
    required this.step,
    required this.totalSteps,
    this.onNext,
    this.onBack,
  }) : assert(step >= 1 && step <= totalSteps);

  final int step;
  final int totalSteps;
  final VoidCallback? onNext; // null when the step auto-advances
  final VoidCallback? onBack; // null on the first step
}

/// A dead end: the flow cannot continue. `instance_gone`,
/// `instance_verification_failed`.
///
/// Not a step, so no position -- showing `(4/7)` on a screen the user can never
/// advance past would be a lie about the state of the world.
final class DeadEndFooter extends ShellFooter {
  const DeadEndFooter({required this.actions});
  final List<ShellAction> actions;
}
