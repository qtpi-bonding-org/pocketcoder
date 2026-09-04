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

/// Horizontal Spacing (Width) - expressed in character units
/// Usage: HSpace.x1, HSpace.x2, etc.
/// One unit = one character width
class HSpace {
  HSpace._();

  static SizedBox get x0_5 => SizedBox(width: AppSizes.ch * 0.5);
  static SizedBox get x1 => SizedBox(width: AppSizes.ch);
  static SizedBox get x1_5 => SizedBox(width: AppSizes.ch * 1.5);
  static SizedBox get x2 => SizedBox(width: AppSizes.ch * 2);
  static SizedBox get x3 => SizedBox(width: AppSizes.ch * 3);
  static SizedBox get x4 => SizedBox(width: AppSizes.ch * 4);
  static SizedBox get x5 => SizedBox(width: AppSizes.ch * 5);
  static SizedBox get x6 => SizedBox(width: AppSizes.ch * 6);
  static SizedBox get x8 => SizedBox(width: AppSizes.ch * 8);
  static SizedBox get x10 => SizedBox(width: AppSizes.ch * 10);
}
