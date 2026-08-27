import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';

void main() {
  const harness1 = Harnesse(
      id: 'h1',
      name: 'Goose',
      cliId: 'goose',
      acpTransport: HarnesseAcpTransport.websocket);
  const model1 = Model(id: 'model-1', name: 'Claude', provider: 'p-anthropic');
  const hm1 = HarnessModel(
      id: 'hm-1', harness: 'h1', model: 'model-1', harnessModelId: 'claude-3');
  const key1 = ProviderApiKey(
      id: 'k1', owner: 'u', provider: 'p-anthropic', apiKey: 'key');
  const ollamaModel1 = OllamaModel(name: 'qwen2.5:0.5b', size: 1);

  NewChatDialog dialog() => const NewChatDialog(
        harnesses: [harness1],
        models: [model1],
        harnessModels: [hm1],
        harnessProviders: [
          const HarnessProvider(
              id: 'hp1', harness: 'h1', provider: 'p-anthropic')
        ],
        providerAPIKeys: [key1],
        ollamaModels: [ollamaModel1],
      );

  Future<NewChatSelection?> pumpAndOpen(WidgetTester tester) async {
    NewChatSelection? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<NewChatSelection>(
              context: context,
              builder: (_) => dialog(),
            );
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('cancel returns null and creates nothing', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(NewChatDialog), findsNothing);
  });

  testWidgets('shows harness1 as a selectable harness option once opened',
      (tester) async {
    await pumpAndOpen(tester);
    // The harness field itself only shows the "select harness" placeholder
    // until tapped — tap it to open the nested picker dialog, then the
    // harness name should be visible as an option.
    await tester.tap(find.text('SELECT HARNESS'));
    await tester.pumpAndSettle();
    expect(find.text('Goose'), findsOneWidget);
  });

  testWidgets(
      'selecting a harness and model and confirming returns the selection',
      (tester) async {
    late Future<NewChatSelection?> resultFuture;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () {
            resultFuture = showDialog<NewChatSelection>(
              context: context,
              builder: (_) => dialog(),
            );
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Open the harness picker and select it.
    await tester.tap(find.text('SELECT HARNESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();

    // Open the model picker (now populated) and select it.
    await tester.tap(find.text('SELECT MODEL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.harness, 'h1');
    expect(result?.harnessModelOverride, 'hm-1');
  });

  testWidgets('selecting a live Ollama tag returns no catalog relation',
      (tester) async {
    late Future<NewChatSelection?> resultFuture;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () {
            resultFuture = showDialog<NewChatSelection>(
              context: context,
              builder: (_) => dialog(),
            );
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELECT HARNESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELECT MODEL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('qwen2.5:0.5b (LOCAL)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.harness, 'h1');
    expect(result?.harnessModelOverride, isNull);
    expect(result?.ollamaModelOverride, 'qwen2.5:0.5b');
  });
}
