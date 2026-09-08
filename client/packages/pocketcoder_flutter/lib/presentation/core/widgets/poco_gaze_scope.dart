import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Tracks the last touch position on screen so any [PocoAnimator]
/// beneath it can look toward it. Installed once near the root of a
/// screen (not per-Poco) so every face on that screen shares one scope.
///
/// `translucent` so this never steals a tap from the app underneath --
/// it only observes.
class PocoGazeScope extends StatefulWidget {
  const PocoGazeScope({super.key, required this.child});

  final Widget child;

  /// Null means no ambient scope (e.g. a Widgetbook story rendered in
  /// isolation), in which case a tap is simply not tracked.
  static ValueListenable<Offset?>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_PocoGazeInherited>()
      ?.notifier;

  @override
  State<PocoGazeScope> createState() => _PocoGazeScopeState();
}

class _PocoGazeScopeState extends State<PocoGazeScope> {
  final ValueNotifier<Offset?> _tapPosition = ValueNotifier(null);

  @override
  void dispose() {
    _tapPosition.dispose();
    super.dispose();
  }

  void _setTapPosition(PointerEvent event) => _tapPosition.value = event.position;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _setTapPosition,
        onPointerMove: _setTapPosition,
        child: _PocoGazeInherited(
          notifier: _tapPosition,
          child: widget.child,
        ),
      );
}

class _PocoGazeInherited extends InheritedNotifier<ValueNotifier<Offset?>> {
  const _PocoGazeInherited({required super.notifier, required super.child});
}
