import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/thinking_block.dart';

void main() {
  testWidgets(
      'the THOUGHTS label renders in the primary (green) color, not warning',
      (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          capturedContext = context;
          return const ThinkingBlock(
            text: 'thinking...',
            isLatest: true,
            isStreaming: false,
          );
        }),
      ),
    ));

    final label = tester.widget<Text>(find.text('[ THOUGHTS ]'));
    final expectedColor = capturedContext.colorScheme.primary;
    expect(label.style?.color, expectedColor);
    expect(label.style?.color, isNot(capturedContext.terminalColors.warning));
  });
}