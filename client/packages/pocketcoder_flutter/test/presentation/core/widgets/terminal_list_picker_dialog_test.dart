import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';

void main() {
  testWidgets('returns the tapped item', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.terminalTheme,
      home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              picked = await showTerminalListPicker<String>(
                context: context,
                title: 'PICK',
                items: const ['alpha', 'beta'],
                itemBuilder: (_, item) => Text(item),
              );
            },
            child: const Text('open'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('[ PICK ]'), findsOneWidget);

    await tester.tap(find.text('beta'));
    await tester.pumpAndSettle();
    expect(picked, 'beta');
  });

  testWidgets('returns null when dismissed', (tester) async {
    String? picked = 'unset';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.terminalTheme,
      home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              picked = await showTerminalListPicker<String>(
                context: context,
                title: 'PICK',
                items: const ['alpha'],
                itemBuilder: (_, item) => Text(item),
              );
            },
            child: const Text('open'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('[ PICK ]'))).pop();
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
