import 'package:flutter/foundation.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';

/// A single action a dead-end footer can offer (e.g. "retry", "contact support").
final class ShellAction {
  const ShellAction({required this.label, required this.kind, required this.onTap});
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
  const PillarFooter(this.active);
  final NavPillar active;
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
    required this.onNext,
    this.onBack,
  }) : assert(step >= 1 && step <= totalSteps);

  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;   // null on the first step
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
