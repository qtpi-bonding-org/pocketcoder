import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/plan_panel.dart';

void main() {
  testWidgets('renders the plan header in vivid green', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PlanPanel(
            plan: const {
              'entries': [
                {'content': 'Inspect the repository', 'status': 'pending'},
              ],
            },
          ),
        ),
      ),
    );

    final header = tester.widget<Text>(find.text('[PLAN]'));
    expect(header.style?.color, const Color(0xFF00FF41));
  });
}
