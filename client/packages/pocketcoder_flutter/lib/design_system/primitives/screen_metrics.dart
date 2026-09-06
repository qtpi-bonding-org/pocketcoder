import 'package:flutter/material.dart';

/// Source of the screen width that [UiScaler] derives its factor from.
/// Lets the Storybook drive a simulated device width without touching
/// any production call site.
abstract interface class ScreenMetrics {
  double get width;
}

/// Production source — reads the live window via MediaQuery.
class MediaQueryScreenMetrics implements ScreenMetrics {
  const MediaQueryScreenMetrics(this.context);
  final BuildContext context;
  @override
  double get width => MediaQuery.of(context).size.width;
}

/// Storybook source — a fixed simulated device width (e.g. iPad @ 820).
class FixedScreenMetrics implements ScreenMetrics {
  const FixedScreenMetrics(this.width);
  @override
  final double width;
}
