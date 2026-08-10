import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/ollama/ollama_api.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockOllamaApi extends Mock implements OllamaApi {}

void main() {
  late MockProviderRepository providerRepo;
  late MockOllamaApi ollamaApi;

  const harness1 = Harnesse(
      id: 'h1',
      name: 'Goose',
      cliId: 'goose',
      acpTransport: HarnesseAcpTransport.websocket);
  const model1 = Model(id: 'model-1', name: 'Claude', provider: 'anthropic');
  const hm1 = HarnessModel(
      id: 'hm-1', harness: 'h1', model: 'model-1', harnessModelId: 'claude-3');
  const key1 = ProviderKey(id: 'k1', user: 'u', provider: 'anthropic');

  setUp(() {
    providerRepo = MockProviderRepository();
    ollamaApi = MockOllamaApi();
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value(const [harness1]));
    when(() => providerRepo.watchModels())
        .thenAnswer((_) => Stream.value(const [model1]));
    when(() => providerRepo.watchHarnessModels())
        .thenAnswer((_) => Stream.value(const [hm1]));
    when(() => providerRepo.watchProviderKeys())
        .thenAnswer((_) => Stream.value(const [key1]));
    when(() => ollamaApi.listModels()).thenAnswer(
      (_) async => const [OllamaModel(name: 'qwen2.5:0.5b', size: 1)],
    );
  });

  NewChatDialog dialog() => NewChatDialog(
        providerRepository: providerRepo,
        loadOllamaModels: ollamaApi.listModels,
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
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
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

    // Open the harness picker (first arrow_drop_down icon) and select it.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();

    // Open the model picker (now populated) and select it.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).at(1));
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
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_drop_down).at(1));
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
