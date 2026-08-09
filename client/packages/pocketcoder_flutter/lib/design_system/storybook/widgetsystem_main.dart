import 'package:flutter/material.dart';
import 'package:flutter_widgetsystem/flutter_widgetsystem.dart' as ws;
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/storybook/pc_palette_adapter.dart';
import 'package:pocketcoder_flutter/design_system/storybook/widgetsystem_main.directories.g.dart';

void main() => runApp(const PocketCoderWidgetbookApp());

@wb.App()
class PocketCoderWidgetbookApp extends StatelessWidget {
  const PocketCoderWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ws.WidgetSystem(
      lightPalette: const PocketCoderPaletteAdapter(),
      themeBuilder: (_) => ThemeData.dark(),
      directories: directories,
    );
  }
}
