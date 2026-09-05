import 'package:flutter/material.dart';
import 'app_sizes.dart';

/// All vertical space must be a multiple of line height; do not use
/// AppSizes.space for vertical gaps as it would place text off-grid.
class VSpace {
  VSpace._();

  static SizedBox get x0_5 => SizedBox(height: AppSizes.line * 0.5);
  static SizedBox get x1 => SizedBox(height: AppSizes.line);
  static SizedBox get x1_5 => SizedBox(height: AppSizes.line * 1.5);
  static SizedBox get x2 => SizedBox(height: AppSizes.line * 2);
  static SizedBox get x3 => SizedBox(height: AppSizes.line * 3);
  static SizedBox get x4 => SizedBox(height: AppSizes.line * 4);
  static SizedBox get x5 => SizedBox(height: AppSizes.line * 5);
  static SizedBox get x6 => SizedBox(height: AppSizes.line * 6);
  static SizedBox get x8 => SizedBox(height: AppSizes.line * 8);
  static SizedBox get x10 => SizedBox(height: AppSizes.line * 10);
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
