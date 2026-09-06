import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

@wb.UseCase(name: 'empty config', type: ConfigPicker)
Widget configPickerEmpty(BuildContext context) => _app(ConfigPicker(
      config: const {'options': []},
      onSetOption: (_) {},
    ));

@wb.UseCase(name: 'boolean and select options', type: ConfigPicker)
Widget configPickerPopulated(BuildContext context) => _app(ConfigPicker(
      config: const {
        'options': [
          {
            'id': 'verbose',
            'name': 'Verbose output',
            'kind': 'boolean',
            'currentValue': true,
          },
          {
            'id': 'mode',
            'name': 'Mode',
            'kind': 'select',
            'currentValue': 'fast',
            'options': [
              {'value': 'fast', 'label': 'Fast'},
              {'value': 'thorough', 'label': 'Thorough'},
            ],
          },
        ],
      },
      onSetOption: (_) {},
    ));
