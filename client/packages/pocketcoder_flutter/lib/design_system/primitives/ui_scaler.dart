import 'package:flutter/material.dart';

/// Singleton utility for responsive UI scaling.
///
/// Calculates a scale factor based on device screen width compared to
/// a baseline design width (iPhone 16 @ 393dp). All dimensions flow
/// through [px] and [sp] to scale proportionally across devices.
class UiScaler {
  UiScaler._();
  static final UiScaler instance = UiScaler._();

  /// Design baseline: iPhone 16 logical width (1179px / 3.0 DPR = 393dp)
  static const double _baseWidth = 393.0;

  late double _screenWidth;
  late double _scaleFactor;
  bool _initialized = false;

  /// Initialize the scaler. Call from MaterialApp.builder.
  void init(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;

    // Clamp to prevent extreme scaling on very small/large devices
    const double minScale = 0.85;
    const double maxScale = 1.15;

    final rawFactor = _screenWidth / _baseWidth;
    _scaleFactor = rawFactor.clamp(minScale, maxScale);
    _initialized = true;
  }

  /// Scale a generic dimension (padding, margin, radius, etc.)
  double px(double value) {
    if (value == 0) return 0;
    if (!_initialized) return value; // Fallback before init
    return value * _scaleFactor;
  }

  /// Scale a font size value. Separated for potential non-linear scaling.
  double sp(double value) {
    if (value == 0) return 0;
    if (!_initialized) return value;
    return value * _scaleFactor;
  }

  /// Current scale factor (for debugging)
  double get scaleFactor => _initialized ? _scaleFactor : 1.0;
}
