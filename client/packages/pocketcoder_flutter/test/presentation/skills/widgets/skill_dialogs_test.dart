import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/skills/widgets/skill_dialogs.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showDialog<void>(context: context, builder: (_) => dialog),
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // PocketBase requires `^[a-z0-9]+(?:-[a-z0-9]+)*$` for skill names.
  testWidgets('AddSkillDialog normalizes a plainly-typed name into a valid slug',
      (tester) async {
    String? submittedName;
    await pumpDialog(
      tester,
      AddSkillDialog(
        configs: const <PocoConfig>[],
        onSubmit: (name, description, content, global, projectDir) {
          submittedName = name;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'My Cool Skill!');
    await tester.enterText(find.byType(TextField).at(1), 'does a thing');
    await tester.enterText(find.byType(TextField).at(2), 'skill body');
    await tester.tap(find.text('<add>'));
    await tester.pumpAndSettle();

    expect(submittedName, 'my-cool-skill');
  });

  testWidgets('SkillEditorDialog normalizes a plainly-typed name into a valid slug',
      (tester) async {
    String? submittedName;
    await pumpDialog(
      tester,
      SkillEditorDialog(
        onSubmit: (name, description, content) {
          submittedName = name;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'My Cool Skill!');
    await tester.enterText(find.byType(TextField).at(1), 'does a thing');
    await tester.enterText(find.byType(TextField).at(2), 'skill body');
    await tester.tap(find.text('<add>'));
    await tester.pumpAndSettle();

    expect(submittedName, 'my-cool-skill');
  });
}
