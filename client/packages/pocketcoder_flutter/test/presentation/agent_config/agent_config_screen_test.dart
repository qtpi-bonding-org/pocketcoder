import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  final config = PocoConfig(id: 'config-1', name: 'Test Config');
  final prompt = Prompt(id: 'prompt-1', name: 'Test Prompt', body: 'hello');
  final permissionMode = PermissionMode(
    id: 'mode-1',
    name: 'Balanced',
    baseSessionMode: PermissionModeBaseSessionMode.approve,
  );

  Future<void> pumpView(
    WidgetTester tester, {
    AgentConfigState state = const AgentConfigState(),
    Future<void> Function(PocoConfig)? onSave,
    Future<void> Function(String)? onDelete,
  }) async {
    await tester.pumpWidget(_wrap(AgentConfigView(
      state: state,
      onSave: onSave ?? (_) async {},
      onDelete: onDelete ?? (_) async {},
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('lists existing configs from plain state', (tester) async {
    await pumpView(tester, state: AgentConfigState(configs: [config]));
    expect(find.text('TEST CONFIG'), findsOneWidget);
  });

  testWidgets('ADD NEW opens the editor dialog', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    expect(find.text('AGENT CONFIGURATION'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DetailRow), findsWidgets);
  });

  testWidgets('existing config prefills the editor', (tester) async {
    await pumpView(tester, state: AgentConfigState(configs: [config]));
    await tester.tap(find.text('TEST CONFIG'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Test Config');
  });

  testWidgets('saving calls the supplied callback', (tester) async {
    PocoConfig? saved;
    await pumpView(tester, onSave: (value) async => saved = value);
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My New Agent');
    await tester.tap(find.text('SAVE').last);
    await tester.pumpAndSettle();
    expect(saved?.name, 'My New Agent');
    expect(saved?.id, '');
  });

  testWidgets('prompt picker lists and selects prompts', (tester) async {
    await pumpView(tester,
        state: AgentConfigState(prompts: [
          prompt,
          Prompt(id: 'prompt-2', name: 'Second Prompt', body: 'b')
        ]));
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SYSTEM PROMPT'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT PROMPT'), findsOneWidget);
    expect(find.text('SECOND PROMPT'), findsOneWidget);
  });

  testWidgets('mode picker lists live permission modes and selects one',
      (tester) async {
    await pumpView(
      tester,
      state: AgentConfigState(permissionModes: [
        permissionMode,
        PermissionMode(
          id: 'mode-2',
          name: 'Autonomous',
          baseSessionMode: PermissionModeBaseSessionMode.auto,
        ),
      ]),
    );
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MODE'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT MODE'), findsOneWidget);
    expect(find.text('BALANCED'), findsOneWidget);
    expect(find.text('AUTONOMOUS'), findsOneWidget);
  });

  testWidgets('is_default toggle works', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    final toggle = find.byType(TerminalCheckbox);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TerminalCheckbox>(toggle).value, false);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TerminalCheckbox>(toggle).value, true);
  });

  testWidgets('deleting calls the supplied callback', (tester) async {
    String? deleted;
    await pumpView(tester,
        state: AgentConfigState(configs: [config]),
        onDelete: (id) async => deleted = id);
    await tester.tap(find.text('TEST CONFIG'));
    await tester.pumpAndSettle();
    final deleteButton = find.text('DELETE').last;
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE').last);
    await tester.pumpAndSettle();
    expect(deleted, 'config-1');
  });
}
