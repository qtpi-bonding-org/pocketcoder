import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';

void main() {
  testWidgets('title sits inside the top border, lowercase, label role',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: DecisionFrame(title: 'confirm', child: Text('body'))),
    ));
    final title = tester.widget<Text>(find.text('confirm'));
    expect(title.style!.color, TextRole.label.color);
    expect(find.text('CONFIRM'), findsNothing);
  });

  testWidgets('border is dim, not trace', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: DecisionFrame(title: 'confirm', child: Text('body'))),
    ));
    final box = tester
        .widget<Container>(find.byKey(const ValueKey('decision-frame-border')));
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppPalette.dim,
        reason:
            'trace measures ~1.5:1 and would be invisible (spec section 6)');
  });

  testWidgets('the glow shadow is gone', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: DecisionFrame(title: 'confirm', child: Text('body'))),
    ));
    final box = tester
        .widget<Container>(find.byKey(const ValueKey('decision-frame-border')));
    expect((box.decoration! as BoxDecoration).boxShadow, isNull,
        reason: 'nothing in the interface glows (spec section 6)');
  });
}
