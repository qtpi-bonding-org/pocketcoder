import 'ui_scaler.dart';

/// Design tokens for all scalable dimensions.
/// Single source of truth for sizes, spacing, radii, and typography scale.
class AppSizes {
  AppSizes._();

  static double get space => UiScaler.instance.px(8.0);

  static double get fontBody => UiScaler.instance.sp(16.0);

  static List<double> get textSizes => [fontBody];

  static double get letterSpacingWide => 2.0;

  static double get iconTiny => UiScaler.instance.sp(8.0);
  static double get iconSmall => UiScaler.instance.sp(16.0);
  static double get iconMedium => UiScaler.instance.sp(24.0);
  static double get iconLarge => UiScaler.instance.sp(32.0);
  static double get iconXLarge => UiScaler.instance.sp(48.0);

  static double get radiusTiny => space * 0.25;
  static double get radiusSmall => space;
  static double get radiusMedium => space * 2;
  static double get radiusLarge => space * 3;

  static double get buttonHeight => space * 6;
  static double get inputHeight => space * 7;
  static double get appBarHeight => space * 7;
  static double get bottomBarHeight => space * 10;
  static double get contentMaxWidth => 500;
  static double get pickerHeight => 300;
  static double get progressIndicatorSize => space * 1.5;
  static double get progressBarHeight => UiScaler.instance.px(4.0);
  static double get provisioningSnippetPreviewMaxHeight => 176;
  static double get provisioningSnippetMaxHeight => 320;

  static double get borderWidth => UiScaler.instance.px(1.0);
  static double get borderWidthThick => UiScaler.instance.px(2.0);
}
