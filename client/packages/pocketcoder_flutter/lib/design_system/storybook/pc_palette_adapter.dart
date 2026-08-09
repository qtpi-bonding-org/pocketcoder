import 'package:flutter/material.dart';
import 'package:flutter_widgetsystem/flutter_widgetsystem.dart' as ws;
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';

class PocketCoderPaletteAdapter implements ws.IColorPalette {
  const PocketCoderPaletteAdapter();

  @override
  String get name => AppPalette.primary.name ?? 'PocketCoder Terminal';

  @override
  Map<String, Color> get colors => Map.unmodifiable(AppPalette.primary.colors);
}
