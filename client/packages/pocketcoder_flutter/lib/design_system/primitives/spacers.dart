import 'package:flutter/material.dart';
import 'app_sizes.dart';

/// Vertical Spacing (Height) - pixel-based
/// Usage: VSpace.x1, VSpace.x2, etc.
/// Note: VSpace values do not map cleanly to line units and are kept
/// as pixel-based spacing for non-text padding (safe-area insets).
class VSpace {
  VSpace._();

  static SizedBox get x0_5 => SizedBox(height: AppSizes.space * 0.5);
  static SizedBox get x1 => SizedBox(height: AppSizes.space);
  static SizedBox get x1_5 => SizedBox(height: AppSizes.space * 1.5);
  static SizedBox get x2 => SizedBox(height: AppSizes.space * 2);
  static SizedBox get x3 => SizedBox(height: AppSizes.space * 3);
  static SizedBox get x4 => SizedBox(height: AppSizes.space * 4);
  static SizedBox get x5 => SizedBox(height: AppSizes.space * 5);
  static SizedBox get x6 => SizedBox(height: AppSizes.space * 6);
  static SizedBox get x8 => SizedBox(height: AppSizes.space * 8);
  static SizedBox get x10 => SizedBox(height: AppSizes.space * 10);
}

/// Horizontal Spacing (Width) - pixel-based
/// Usage: HSpace.x1, HSpace.x2, etc.
/// Note: HSpace remains pixel-based (like VSpace) for now. Full conversion
/// to character units requires careful layout review across all call sites
/// to avoid overflow issues at constrained widths (tracked for future task).
class HSpace {
  HSpace._();

  static SizedBox get x0_5 => SizedBox(width: AppSizes.space * 0.5);
  static SizedBox get x1 => SizedBox(width: AppSizes.space);
  static SizedBox get x1_5 => SizedBox(width: AppSizes.space * 1.5);
  static SizedBox get x2 => SizedBox(width: AppSizes.space * 2);
  static SizedBox get x3 => SizedBox(width: AppSizes.space * 3);
  static SizedBox get x4 => SizedBox(width: AppSizes.space * 4);
  static SizedBox get x5 => SizedBox(width: AppSizes.space * 5);
  static SizedBox get x6 => SizedBox(width: AppSizes.space * 6);
  static SizedBox get x8 => SizedBox(width: AppSizes.space * 8);
  static SizedBox get x10 => SizedBox(width: AppSizes.space * 10);
}
