import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
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

  NewChatDialog dialog({
    List<Harnesse> harnesses = const [harness1],
    List<Model> models = const [model1],
    List<HarnessModel> harnessModels = const [hm1],
    List<domain.Provider> providers = const [],
    List<ProviderApiKey> providerAPIKeys = const [key1],
  }) =>
      NewChatDialog(
        harnesses: harnesses,
        models: models,
        harnessModels: harnessModels,
        harnessProviders: const [
          HarnessProvider(id: 'hp1', harness: 'h1', provider: 'p-anthropic')
        ],
        providers: providers,
        providerAPIKeys: providerAPIKeys,
        ollamaModels: const [ollamaModel1],
      );

  Future<NewChatSelection?> pumpAndOpen(
    WidgetTester tester, {
    NewChatDialog Function()? build,
  }) async {
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
              builder: (_) => (build ?? dialog)(),
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
    await tester.tap(find.text('<cancel>'));
    await tester.pumpAndSettle();
    expect(find.byType(NewChatDialog), findsNothing);
  });

  testWidgets('shows harness1 as a selectable harness option once opened',
      (tester) async {
    await pumpAndOpen(tester);
    // The harness field itself only shows the "select harness" placeholder
    // until tapped — tap it to open the nested picker dialog, then the
    // harness name should be visible as an option.
    await tester.tap(find.text('select harness'));
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
    await tester.tap(find.text('select harness'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();

    // Open the model picker (now populated) and select it.
    await tester.tap(find.text('select model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('<create>'));
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
    await tester.tap(find.text('select harness'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('select model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('qwen2.5:0.5b (LOCAL)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('<create>'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.harness, 'h1');
    expect(result?.harnessModelOverride, isNull);
    expect(result?.ollamaModelOverride, 'qwen2.5:0.5b');
  });

  group('fanout harness (Goose/OpenCode-style) model filtering', () {
    const fanoutHarness = Harnesse(
        id: 'h2',
        name: 'Goose',
        cliId: 'goose',
        acpTransport: HarnesseAcpTransport.websocket,
        providerFanout: true);
    const keyedModel =
        Model(id: 'model-keyed', name: 'Claude', provider: 'p-anthropic');
    const unkeyedModel =
        Model(id: 'model-unkeyed', name: 'GPT', provider: 'p-openai');
    const hmKeyed = HarnessModel(
        id: 'hm-keyed',
        harness: 'h2',
        model: 'model-keyed',
        harnessModelId: 'claude-3');
    const hmUnkeyed = HarnessModel(
        id: 'hm-unkeyed',
        harness: 'h2',
        model: 'model-unkeyed',
        harnessModelId: 'gpt-5');
    const anthropicKey = ProviderApiKey(
        id: 'k1', owner: 'u', provider: 'p-anthropic', apiKey: 'key');

    testWidgets(
        'hides models whose provider has no configured credential',
        (tester) async {
      await pumpAndOpen(
        tester,
        build: () => dialog(
          harnesses: const [fanoutHarness],
          models: const [keyedModel, unkeyedModel],
          harnessModels: const [hmKeyed, hmUnkeyed],
          providerAPIKeys: const [anthropicKey],
        ),
      );
      await tester.tap(find.text('select harness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('select model'));
      await tester.pumpAndSettle();

      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('GPT'), findsNothing);
    });

    testWidgets('groups the model list by provider name', (tester) async {
      await pumpAndOpen(
        tester,
        build: () => dialog(
          harnesses: const [fanoutHarness],
          models: const [keyedModel, unkeyedModel],
          harnessModels: const [hmKeyed, hmUnkeyed],
          providers: const [
            domain.Provider(
                id: 'p-anthropic', providerId: 'anthropic', name: 'Anthropic'),
            domain.Provider(
                id: 'p-openai', providerId: 'openai', name: 'OpenAI'),
          ],
          providerAPIKeys: const [
            anthropicKey,
            ProviderApiKey(
                id: 'k2', owner: 'u', provider: 'p-openai', apiKey: 'key2'),
          ],
        ),
      );
      await tester.tap(find.text('select harness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('select model'));
      await tester.pumpAndSettle();

      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
    });
  });
}
