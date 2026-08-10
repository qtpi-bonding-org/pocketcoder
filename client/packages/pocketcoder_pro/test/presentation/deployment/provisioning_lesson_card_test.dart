import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/provisioning_lesson_card.dart';

void main() {
  testWidgets('shows an important excerpt and expands every complete block',
      (tester) async {
    var expanded = false;

    Widget buildCard() => MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ProvisioningLessonCard(
                title: 'Safe image installation',
                explanation: 'I verify the disk and image before installation.',
                importantCode: 'test -b /dev/sdb',
                codeBlocks: const [
                  ProvisioningLessonCodeBlock(
                    title: 'Check the disk',
                    sourceLabel: 'installer.sh:10',
                    code: 'blockdev --getsize64 /dev/sdb',
                  ),
                  ProvisioningLessonCodeBlock(
                    title: 'Verify the image',
                    sourceLabel: 'installer.sh:34',
                    code: 'sha256sum /tmp/image',
                  ),
                ],
                lessonNumber: 1,
                lessonCount: 10,
                expanded: expanded,
                onExpandedChanged: (value) {
                  setState(() => expanded = value);
                },
                onNext: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildCard());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('test -b /dev/sdb'), findsOneWidget);
    expect(find.text('blockdev --getsize64 /dev/sdb'), findsNothing);
    expect(find.text('SHOW FULL SECTION (2)'), findsOneWidget);

    await tester.tap(find.text('SHOW FULL SECTION (2)'));
    await tester.pump();

    expect(find.text('blockdev --getsize64 /dev/sdb'), findsOneWidget);
    expect(find.text('sha256sum /tmp/image'), findsOneWidget);
    expect(find.text('installer.sh:10'), findsOneWidget);
    expect(find.text('installer.sh:34'), findsOneWidget);
    expect(find.text('SHOW CONCISE VIEW'), findsOneWidget);
  });
}
