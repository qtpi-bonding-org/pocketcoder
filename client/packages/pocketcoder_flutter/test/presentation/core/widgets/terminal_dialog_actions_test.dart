import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders confirm label and calls onConfirm when tapped',
      (tester) async {
    var confirmed = false;
    await tester.pumpWidget(_app(
      TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: () => confirmed = true,
      ),
    ));

    expect(find.text('SAVE'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(confirmed, isTrue);
  });

  testWidgets('renders cancel label only when provided', (tester) async {
    await tester.pumpWidget(_app(
      const TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: null,
      ),
    ));
    expect(find.text('CANCEL'), findsNothing);

    var cancelled = false;
    await tester.pumpWidget(_app(
      TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: () {},
        cancelLabel: 'CANCEL',
        onCancel: () => cancelled = true,
      ),
    ));
    expect(find.text('CANCEL'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    expect(cancelled, isTrue);
  });

  testWidgets('disables confirm when confirmEnabled is false', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(_app(
      TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: () => confirmed = true,
        confirmEnabled: false,
      ),
    ));

    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(confirmed, isFalse);
  });
}
