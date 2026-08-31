import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('row variant with onTap shows a chevron and is tappable',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(BiosRow(
      label: 'settings',
      onTap: () => tapped = true,
    )));

    expect(find.text('[>]'), findsOneWidget);
    await tester.tap(find.byType(BiosRow));
    expect(tapped, isTrue);
  });

  testWidgets('row variant with a value shows the value, not a chevron',
      (tester) async {
    await tester.pumpWidget(_app(const BiosRow(
      label: 'mode',
      value: 'auto',
      onTap: null,
    )));

    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('[>]'), findsNothing);
  });

  testWidgets('row variant with no onTap renders without an InkWell',
      (tester) async {
    await tester.pumpWidget(_app(const BiosRow(
      label: 'created',
      value: '2026-08-23',
    )));

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets(
      'toggle variant renders a terminal-style [ ]/[X] glyph and forwards '
      'changes', (tester) async {
    bool? changedTo;
    await tester.pumpWidget(_app(BiosRow(
      label: 'enabled',
      variant: BiosRowVariant.toggle,
      toggleValue: false,
      onToggleChanged: (v) => changedTo = v,
    )));

    expect(find.byType(Switch), findsNothing);
    expect(find.text('[ ]'), findsOneWidget);
    await tester.tap(find.text('[ ]'));
    expect(changedTo, isTrue);
  });

  testWidgets('toggle variant shows [X] when toggleValue is true',
      (tester) async {
    await tester.pumpWidget(_app(const BiosRow(
      label: 'enabled',
      variant: BiosRowVariant.toggle,
      toggleValue: true,
    )));

    expect(find.text('[X]'), findsOneWidget);
    expect(find.text('[ ]'), findsNothing);
  });

  testWidgets('input variant renders a text field and forwards changes',
      (tester) async {
    String? typed;
    final controller = TextEditingController();
    await tester.pumpWidget(_app(BiosRow(
      label: 'code',
      variant: BiosRowVariant.input,
      inputController: controller,
      onInputChanged: (v) => typed = v,
    )));

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    expect(typed, '123456');
  });

  testWidgets('expand variant shows [v] collapsed and [^] expanded',
      (tester) async {
    await tester.pumpWidget(_app(const BiosRow(
      label: 'provider',
      variant: BiosRowVariant.expand,
      isExpanded: false,
    )));
    expect(find.text('[v]'), findsOneWidget);

    await tester.pumpWidget(_app(const BiosRow(
      label: 'provider',
      variant: BiosRowVariant.expand,
      isExpanded: true,
    )));
    expect(find.text('[^]'), findsOneWidget);
  });
}
