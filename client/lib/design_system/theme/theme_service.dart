import 'package:injectable/injectable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';
import '../primitives/app_palette.dart';

@singleton
class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;

  IColorPalette get currentPalette =>
      _isDarkMode ? AppPalette.dark : AppPalette.primary;

  bool get isDarkMode => _isDarkMode;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }
}
