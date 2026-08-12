import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/walkthrough_snippet.dart';

void main() {
  testWidgets('reveals only the complete snippet for the concept',
      (tester) async {
    var expanded = false;

    Widget buildView() => MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => WalkthroughSnippet(
                previewCode: 'public = true;',
                expandedCode: 'public = true;\nprivate = false;',
                sourceLabel: 'configuration.nix:42-58',
                expanded: expanded,
                onExpandedChanged: (value) {
                  setState(() => expanded = value);
                },
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildView());

    expect(find.text('public = true;'), findsOneWidget);
    expect(find.text('private = false;'), findsNothing);
    expect(find.text('configuration.nix:42-58'), findsOneWidget);
    expect(find.text('SHOW FULL SNIPPET'), findsOneWidget);

    await tester.tap(find.text('SHOW FULL SNIPPET'));
    await tester.pump();

    expect(
      find.text('public = true;\nprivate = false;'),
      findsOneWidget,
    );
    expect(find.text('SHOW PREVIEW'), findsOneWidget);
  });
}
