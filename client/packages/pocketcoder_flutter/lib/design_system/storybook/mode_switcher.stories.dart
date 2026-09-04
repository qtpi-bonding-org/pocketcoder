import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/mode_switcher.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: child);

@wb.UseCase(name: 'no modes', type: ModeSwitcher)
Widget modeSwitcherEmpty(BuildContext context) =>
    _app(const ModeSwitcher(modes: null, onSelectMode: _noop));

@wb.UseCase(name: 'selectable modes', type: ModeSwitcher)
Widget modeSwitcherPopulated(BuildContext context) => _app(ModeSwitcher(
      modes: const {
        'currentModeId': 'smart',
        'availableModes': [
          {'id': 'auto', 'name': 'Auto'},
          {'id': 'smart', 'name': 'Smart approve'},
          {'id': 'chat', 'name': 'Chat'},
        ]
      },
      onSelectMode: (_) {},
    ));

void _noop(String _) {}
