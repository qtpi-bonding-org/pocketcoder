import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_value_widget.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';

@wb.UseCase(name: 'happy message', type: PocoValueWidget)
Widget pocoValueWidgetHappy(BuildContext context) {
  return PocoValueWidget(
    message: ValueNotifier('Identity verified. Welcome home.'),
    sequence: ValueNotifier(const [('happy', 5000)]),
    history: ValueNotifier(const <String>[]),
    pocoSize: 48,
    posture: PocoPosture.armored,
  );
}

@wb.UseCase(name: 'error message', type: PocoValueWidget)
Widget pocoValueWidgetError(BuildContext context) {
  return PocoValueWidget(
    message: ValueNotifier('ACCESS DENIED. CHECK CREDENTIALS.'),
    sequence: ValueNotifier(const [('nervous', 1000)]),
    history: ValueNotifier(const ['Connecting to server...']),
    pocoSize: 48,
    posture: PocoPosture.armored,
  );
}
