import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';

void main() {
  testWidgets('renders a child in a constrained scroll view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingContentShell(child: Text('content')),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OnboardingContentShell),
        matching: find.byType(ConstrainedBox),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders list builder content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingContentShell(
          listBuilder: (_) => ListView(children: const [Text('list')]),
        ),
      ),
    );

    expect(find.text('list'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}