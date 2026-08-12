import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/storybook/widgetsystem_main.directories.g.dart';

void main() => runApp(const PocketCoderWidgetbookApp());

@wb.App()
class PocketCoderWidgetbookApp extends StatelessWidget {
  const PocketCoderWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      lightTheme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.dark,
      directories: directories,
    );
  }
}
