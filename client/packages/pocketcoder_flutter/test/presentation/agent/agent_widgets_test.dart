import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/mode_switcher.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('ModeSwitcher renders modes and reports selection', (tester) async {
    String? selected;
    await tester.pumpWidget(_wrap(ModeSwitcher(
      modes: {
        'currentModeId': 'auto',
        'availableModes': [
          {'id': 'auto', 'name': 'Auto'},
          {'id': 'chat', 'name': 'Chat'},
        ],
      },
      onSelectMode: (id) => selected = id,
    )));
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('CHAT'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('CHAT'), findsOneWidget);

    await tester.tap(find.text('CHAT').last);
    await tester.pumpAndSettle();
    expect(selected, 'chat');
  });

  testWidgets('ConfigPicker renders options and reports changes', (tester) async {
    SetSessionConfigOptionRequest? request;
    await tester.pumpWidget(_wrap(ConfigPicker(
      config: {
        'options': [
          {'kind': 'boolean', 'id': 'auto-approve', 'name': 'Auto Approve', 'currentValue': false},
          {
            'kind': 'select', 'id': 'preset', 'name': 'Preset', 'currentValue': 'safe',
            'options': [{'value': 'safe', 'label': 'Safe'}, {'value': 'fast', 'label': 'Fast'}],
          },
        ],
      },
      onSetOption: (value) => request = value,
    )));
    await tester.tap(find.text('CONFIG'));
    await tester.pumpAndSettle();
    expect(find.text('AUTO APPROVE'), findsOneWidget);
    expect(find.text('PRESET'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(request?.configId, 'auto-approve');
    expect(request?.value, 'true');
  });
}
