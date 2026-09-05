import 'package:flutter/widgets.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';

/// Armor says where the user is, so the page's chrome declares it once
/// instead of every face being told.
class PocoPostureScope extends InheritedWidget {
  const PocoPostureScope({
    super.key,
    required this.posture,
    required super.child,
  });

  final PocoPosture posture;

  /// No scope means no shell, which is the unarmored case (boot).
  static PocoPosture of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PocoPostureScope>()?.posture ??
      PocoPosture.armored;

  @override
  bool updateShouldNotify(PocoPostureScope oldWidget) =>
      posture != oldWidget.posture;
}
