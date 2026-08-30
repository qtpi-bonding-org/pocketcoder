import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  final config = PocoConfig(id: 'config-1', name: 'Test Config', harnessModel: 'hm-1');
  final prompt = Prompt(id: 'prompt-1', name: 'Test Prompt', body: 'hello');
  final model = HarnessModel(id: 'hm-1', harness: 'h-1', model: 'm-1', harnessModelId: 'harness::model');

  Future<void> pumpView(WidgetTester tester, {
    AgentConfigState state = const AgentConfigState(),
    ProviderState providerState = const ProviderState(),
    Future<void> Function(PocoConfig)? onSave,
    Future<void> Function(String)? onDelete,
  }) async {
    await tester.pumpWidget(_wrap(AgentConfigView(
      state: state,
      providerState: providerState,
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
    expect(find.byType(BiosRow), findsWidgets);
  });

  testWidgets('existing config prefills the editor', (tester) async {
    await pumpView(tester, state: AgentConfigState(configs: [config]));
    await tester.tap(find.text('TEST CONFIG'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Test Config');
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
    await pumpView(tester, state: AgentConfigState(prompts: [prompt, Prompt(id: 'prompt-2', name: 'Second Prompt', body: 'b')]));
    await tester.tap(find.text('ADD NEW')); await tester.pumpAndSettle();
    await tester.tap(find.text('SYSTEM PROMPT')); await tester.pumpAndSettle();
    expect(find.text('SELECT PROMPT'), findsOneWidget);
    expect(find.text('SECOND PROMPT'), findsOneWidget);
  });

  testWidgets(
      'harness model picker lists models grouped by harness display name',
      (tester) async {
    await pumpView(
      tester,
      providerState: ProviderState(
        harnesses: [
          Harnesse(
            id: 'h-1',
            name: 'Goose',
            cliId: 'goose',
            acpTransport: HarnesseAcpTransport.websocket,
          ),
        ],
        harnessModels: [model],
      ),
    );
    await tester.tap(find.text('ADD NEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HARNESS MODEL'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT HARNESS MODEL'), findsOneWidget);
    expect(find.text('GOOSE'), findsOneWidget);
    expect(find.text('HARNESS::MODEL'), findsOneWidget);
  });

  testWidgets('mode picker lists modes', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('ADD NEW')); await tester.pumpAndSettle();
    await tester.tap(find.text('MODE')); await tester.pumpAndSettle();
    expect(find.text('SELECT MODE'), findsOneWidget);
    expect(find.text('APPROVE'), findsOneWidget);
  });

  testWidgets('is_default toggle works', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('ADD NEW')); await tester.pumpAndSettle();
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, false);
    await tester.tap(toggle); await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, true);
  });

  testWidgets('deleting calls the supplied callback', (tester) async {
    String? deleted;
    await pumpView(tester, state: AgentConfigState(configs: [config]), onDelete: (id) async => deleted = id);
    await tester.tap(find.text('TEST CONFIG')); await tester.pumpAndSettle();
    final deleteButton = find.text('DELETE').last;
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton); await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE').last); await tester.pumpAndSettle();
    expect(deleted, 'config-1');
  });
}
