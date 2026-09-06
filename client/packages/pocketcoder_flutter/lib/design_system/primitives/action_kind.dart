import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

/// A discrete pressable button. Renders as `<label>`; pressed state is
/// reverse video.
///
/// Note what is absent: there is no way to give a refusal the color red.
/// Refusing changes nothing and is the safe choice; red on the cautious option
/// teaches the user that caution is dangerous.
enum ActionKind {
  /// The recommended action.
  primary(TextRole.value),

  /// An ordinary action.
  neutral(TextRole.body),

  /// Deny, cancel, decline, no. Amber at most -- never red.
  refusal(TextRole.warn),

  /// Delete, wipe, reset, roll back. Red, and never in first position.
  /// Only constructible from app-defined semantics -- see spec section 14.6.
  destructive(TextRole.fail);

  const ActionKind(this.role);
  final TextRole role;

  bool get mayLeadRow => this != ActionKind.destructive;
}
