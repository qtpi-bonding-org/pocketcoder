import 'package:flutter/material.dart';
import 'package:flutter_widgetsystem/flutter_widgetsystem.dart' as ws;
import 'package:pocketcoder_flutter/design_system/storybook/pc_palette_adapter.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'widgetbook_screens.dart';

void main() => runApp(const PocketCoderProWidgetbookApp());

class PocketCoderProWidgetbookApp extends StatelessWidget {
  const PocketCoderProWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) => ws.WidgetSystem(
        lightPalette: const PocketCoderPaletteAdapter(),
        themeBuilder: (_) => AppTheme.lightTheme,
        directories: [
          WidgetbookFolder(
            name: 'Screens',
            children: screenDirectories,
          ),
        ],
      );
}
