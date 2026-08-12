import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/walkthrough_brief.dart';

void main() {
  testWidgets('shows a concise preview and expands every complete block',
      (tester) async {
    var expanded = false;

    Widget buildCard() => MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => WalkthroughBrief(
                title: 'Safe image installation',
                explanation: 'I verify the disk and image before installation.',
                codeBlocks: const [
                  WalkthroughSnippetBlock(
                    title: 'Check the disk',
                    sourceLabel: 'installer.sh:10',
                    code: 'blockdev --getsize64 /dev/sdb',
                    previewCode: 'test -b /dev/sdb',
                  ),
                  WalkthroughSnippetBlock(
                    title: 'Verify the image',
                    sourceLabel: 'installer.sh:34',
                    code: 'sha256sum /tmp/image',
                    previewCode: 'test -f /tmp/image',
                  ),
                ],
                briefNumber: 1,
                briefCount: 10,
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
    expect(find.text('test -f /tmp/image'), findsOneWidget);
    expect(find.text('blockdev --getsize64 /dev/sdb'), findsNothing);
    expect(find.text('SHOW FULL CODE (2)'), findsOneWidget);

    await tester.tap(find.text('SHOW FULL CODE (2)'));
    await tester.pump();

    expect(find.text('blockdev --getsize64 /dev/sdb'), findsOneWidget);
    expect(find.text('sha256sum /tmp/image'), findsOneWidget);
    expect(find.text('installer.sh:10'), findsOneWidget);
    expect(find.text('installer.sh:34'), findsOneWidget);
    expect(find.text('SHOW CONCISE CODE'), findsOneWidget);
  });
}
