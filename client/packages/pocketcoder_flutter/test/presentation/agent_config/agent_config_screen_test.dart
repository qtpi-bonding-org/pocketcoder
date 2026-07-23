// Widget tests for the AgentConfigScreen (plan Task 11 Step 1).
//
// Mirrors `permission_card_test.dart`'s `_wrap`/`pumpWidget` pattern (the
// same one `agent_widgets_test.dart` uses) — wraps the view in a
// `MaterialApp` with `AppTheme.lightTheme` + the l10n delegates so
// `context.l10n.*` resolves during the test, then injects the real cubits
// fed by fakes implementing the repository interfaces so the production
// widgets exercise the production cubit glue (status state, UiFlowListener-
// driven loading UI).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/agent_config_screen.dart';

/// Fake [IAgentConfigRepository] used as a swap-in for the real
/// PocketBase-backed repository in widget tests.
class _FakeAgentConfigRepository implements IAgentConfigRepository {
  _FakeAgentConfigRepository({
    List<PocoConfig> initialConfigs = const [],
    List<Prompt> initialPrompts = const [],
  })  : _configs = [...initialConfigs],
        _prompts = [...initialPrompts];

  final List<PocoConfig> _configs;
  final List<Prompt> _prompts;

  final List<PocoConfig> savedConfigs = [];
  final List<String> deletedConfigIds = [];

  @override
  Stream<List<PocoConfig>> watchConfigs() async* {
    yield List.unmodifiable(_configs);
  }

  @override
  Stream<List<Prompt>> watchPrompts() async* {
    yield List.unmodifiable(_prompts);
  }

  @override
  Future<void> saveConfig(PocoConfig config) async {
    savedConfigs.add(config);
  }

  @override
  Future<void> deleteConfig(String id) async {
    deletedConfigIds.add(id);
  }

  @override
  Future<void> savePrompt(Prompt prompt) async {}

  @override
  Future<void> deletePrompt(String id) async {}
}

class _FakeProviderRepository implements IProviderRepository {
  _FakeProviderRepository({
    List<HarnessModel> initialHarnessModels = const [],
  }) : _harnessModels = [...initialHarnessModels];

  final List<HarnessModel> _harnessModels;

  @override
  Stream<List<Harnesse>> watchHarnesses() async* {
    yield const [];
  }

  @override
  Stream<List<Model>> watchModels() async* {
    yield const [];
  }

  @override
  Stream<List<HarnessModel>> watchHarnessModels() async* {
    yield List.unmodifiable(_harnessModels);
  }

  @override
  Stream<List<ProviderKey>> watchProviderKeys() async* {
    yield const [];
  }

  @override
  Future<void> saveProviderKey(ProviderKey key) async {}

  @override
  Future<void> deleteProviderKey(String id) async {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  final testConfig = PocoConfig(
    id: 'config-1',
    name: 'Test Config',
    harnessModel: 'hm-1',
  );

  final testPrompt = Prompt(
    id: 'prompt-1',
    name: 'Test Prompt',
    body: 'hello',
  );

  final testHarnessModel = HarnessModel(
    id: 'hm-1',
    harness: 'h-1',
    model: 'm-1',
    harnessModelId: 'harness::model',
  );

  group('AgentConfigScreen', () {
    late _FakeAgentConfigRepository configRepo;
    late _FakeProviderRepository providerRepo;
    late AgentConfigCubit configCubit;
    late ProviderCubit providerCubit;

    Widget wrapWithCubits(Widget child) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<AgentConfigCubit>.value(value: configCubit),
          BlocProvider<ProviderCubit>.value(value: providerCubit),
        ],
        child: child,
      );
    }

    setUp(() {
      configRepo = _FakeAgentConfigRepository();
      providerRepo = _FakeProviderRepository();
      configCubit = AgentConfigCubit(configRepo);
      providerCubit = ProviderCubit(providerRepo);
    });

    tearDown(() async {
      await configCubit.close();
      await providerCubit.close();
    });

    testWidgets('lists existing configs from cubit state', (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      // Seed the repository after the cubit is wired (the cubit's watch
      // stream re-emits as the underlying list mutates).
      configRepo
        ..saveConfig(testConfig)
        ..savePrompt(testPrompt);

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      expect(find.text('TEST CONFIG'), findsOneWidget);
    });

    testWidgets('ADD NEW opens the editor dialog with empty fields',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      expect(find.text('ADD NEW'), findsOneWidget);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      // Dialog opened: title shown and name field present.
      expect(find.text('AGENT CONFIGURATION'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'opening editor for an existing config prefills name in the field',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configRepo
        ..saveConfig(testConfig)
        ..savePrompt(testPrompt);

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('TEST CONFIG'));
      await _settle(tester);

      // The dialog title should reflect the existing config's name.
      expect(
        find.text('AGENT CONFIG: TEST CONFIG'),
        findsOneWidget,
      );
      // And the text field should have the existing name prefilled.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Test Config');
    });

    testWidgets(
        'saving a new config calls cubit.saveConfig with the constructed PocoConfig',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      // Type a name and save.
      await tester.enterText(find.byType(TextField), 'My New Agent');
      await _settle(tester);

      await tester.tap(find.text('SAVE').last);
      await _settle(tester);

      expect(configRepo.savedConfigs, hasLength(1));
      expect(configRepo.savedConfigs.single.name, 'My New Agent');
      expect(configRepo.savedConfigs.single.id, '');
      expect(configRepo.savedConfigs.single.harnessModel, '');
      expect(configRepo.savedConfigs.single.isDefault, false);
    });

    testWidgets('prompt picker lists prompts and selects one',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configRepo
        ..savePrompt(testPrompt)
        ..savePrompt(
          Prompt(id: 'prompt-2', name: 'Second Prompt', body: 'b'),
        );

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      // Tap the prompt picker field.
      await tester.tap(find.text('SYSTEM PROMPT'));
      await _settle(tester);

      // The picker dialog lists both prompts.
      expect(find.text('SELECT PROMPT'), findsOneWidget);
      expect(find.text('TEST PROMPT'), findsOneWidget);
      expect(find.text('SECOND PROMPT'), findsOneWidget);

      // Pick "Second Prompt" — picker closes, the field updates.
      await tester.tap(find.text('SECOND PROMPT'));
      await _settle(tester);
      expect(find.text('SECOND PROMPT'), findsOneWidget);
    });

    testWidgets('harness_model picker lists models and selects one',
        (tester) async {
      // Rebuild the provider cubit with the harness model preloaded.
      await providerCubit.close();
      providerRepo = _FakeProviderRepository(
        initialHarnessModels: [testHarnessModel],
      );
      providerCubit = ProviderCubit(providerRepo);

      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      await tester.tap(find.text('HARNESS MODEL'));
      await _settle(tester);

      expect(find.text('SELECT HARNESS MODEL'), findsOneWidget);
      expect(find.text('HARNESS::MODEL'), findsOneWidget);

      await tester.tap(find.text('HARNESS::MODEL'));
      await _settle(tester);
      expect(find.text('HARNESS::MODEL'), findsOneWidget);
    });

    testWidgets('mode picker lists modes and selects one', (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      await tester.tap(find.text('MODE'));
      await _settle(tester);

      expect(find.text('SELECT MODE'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('SMART APPROVE'), findsOneWidget);
      expect(find.text('CHAT'), findsOneWidget);

      await tester.tap(find.text('APPROVE'));
      await _settle(tester);

      // After selection, the picker field reads APPROVE.
      expect(find.text('APPROVE'), findsOneWidget);
    });

    testWidgets('is_default toggle works via Switch', (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('ADD NEW'));
      await _settle(tester);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, false);

      await tester.tap(switchFinder);
      await _settle(tester);

      expect(tester.widget<Switch>(switchFinder).value, true);
    });

    testWidgets('deleting an existing config calls cubit.deleteConfig',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubits(const AgentConfigView()),
      ));

      configRepo.saveConfig(testConfig);

      configCubit.watchAll();
      providerCubit.watchAll();
      await _settle(tester);

      await tester.tap(find.text('TEST CONFIG'));
      await _settle(tester);

      // Tap the DELETE button inside the edit dialog.
      await tester.tap(find.text('DELETE').last);
      await _settle(tester);

      // Confirmation dialog appears.
      expect(find.text('DELETE CONFIG?'), findsOneWidget);
      // The "DELETE {name}" body uses the existing config's name uppercased.
      expect(
        find.text('DELETE TEST CONFIG? THIS CANNOT BE UNDONE.'),
        findsOneWidget,
      );

      // Confirm.
      await tester.tap(find.text('DELETE'));
      await _settle(tester);

      expect(configRepo.deletedConfigIds, ['config-1']);
    });
  });
}
