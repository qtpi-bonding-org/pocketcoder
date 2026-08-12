import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/pocketcoder_progress_pane.dart';

void main() {
  testWidgets('shows both phases and their current CLI steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PocketCoderProgressPane(
            provision: const PocketCoderProgressPhase(
              label: 'Provision Server',
              progress: 1,
              currentStep: 'Server created · connection secured',
              state: PocketCoderProgressPhaseState.complete,
            ),
            deploy: const PocketCoderProgressPhase(
              label: 'Deploy PocketCoder',
              progress: 0.4,
              currentStep: 'Fetching verified release',
              state: PocketCoderProgressPhaseState.running,
            ),
          ),
        ),
      ),
    );

    expect(find.text('PROVISION SERVER'), findsOneWidget);
    expect(find.text('DEPLOY POCKETCODER'), findsOneWidget);
    expect(find.text(r'$ SERVER CREATED · CONNECTION SECURED'), findsOneWidget);
    expect(find.text(r'$ FETCHING VERIFIED RELEASE'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });
}
