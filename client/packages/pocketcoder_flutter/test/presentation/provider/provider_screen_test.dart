// Widget tests for ProviderScreen / ProviderView (plan Task 12).
//
// Mirrors `agent_config_screen_test.dart`'s `_wrap`/`pumpWidget` pattern so
// context.l10n.* resolves during the test, then injects the real
// ProviderCubit fed by a fake IProviderRepository.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/provider/provider_screen.dart';

/// Fake [IProviderRepository] used as a swap-in for the real
/// PocketBase-backed repository in widget tests.
class _FakeProviderRepository implements IProviderRepository {
  _FakeProviderRepository({
    List<Harnesse> initialHarnesses = const [],
    List<Model> initialModels = const [],
    List<HarnessModel> initialHarnessModels = const [],
    List<ProviderKey> initialProviderKeys = const [],
    this.neverEmit = false,
  })  : _harnesses = [...initialHarnesses],
        _models = [...initialModels],
        _harnessModels = [...initialHarnessModels],
        _providerKeys = [...initialProviderKeys];

  final List<Harnesse> _harnesses;
  final List<Model> _models;
  final List<HarnessModel> _harnessModels;
  final List<ProviderKey> _providerKeys;

  /// When true, every watch* stream stays open without ever emitting — used
  /// to deterministically pin the cubit in its loading state, since a
  /// single-yield `async*` stream otherwise resolves within the same
  /// `pump()` the loading frame would need to be observed in.
  final bool neverEmit;

  final List<ProviderKey> savedKeys = [];
  final List<String> deletedKeyIds = [];

  @override
  Stream<List<Harnesse>> watchHarnesses() async* {
    if (neverEmit) return;
    yield List.unmodifiable(_harnesses);
  }

  @override
  Stream<List<Model>> watchModels() async* {
    if (neverEmit) return;
    yield List.unmodifiable(_models);
  }

  @override
  Stream<List<HarnessModel>> watchHarnessModels() async* {
    if (neverEmit) return;
    yield List.unmodifiable(_harnessModels);
  }

  @override
  Stream<List<ProviderKey>> watchProviderKeys() async* {
    if (neverEmit) return;
    yield List.unmodifiable(_providerKeys);
  }

  @override
  Future<void> saveProviderKey(ProviderKey key) async {
    savedKeys.add(key);
    _providerKeys.removeWhere((k) => k.id == key.id);
    _providerKeys.add(key);
  }

  @override
  Future<void> deleteProviderKey(String id) async {
    deletedKeyIds.add(id);
    _providerKeys.removeWhere((k) => k.id == id);
  }
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

void main() {
  final testHarnesse = Harnesse(
    id: 'h-1',
    name: 'Goose',
    cliId: 'goose',
    acpTransport: HarnesseAcpTransport.websocket,
  );

  final testModel = Model(
    id: 'm-1',
    name: 'sonnet',
    displayName: 'Claude Sonnet',
    provider: 'anthropic',
  );

  final testHarnessModel = HarnessModel(
    id: 'hm-1',
    harness: 'h-1',
    model: 'm-1',
    harnessModelId: 'goose::sonnet',
    isDefault: true,
  );

  final testProviderKey = ProviderKey(
    id: 'pk-1',
    user: 'u-1',
    provider: 'goose',
    envVars: <String, dynamic>{'API_KEY': 'sk-supersecret'},
  );

  group('ProviderScreen', () {
    late _FakeProviderRepository repo;
    late ProviderCubit cubit;

    Widget wrapWithCubit(Widget child) {
      return BlocProvider<ProviderCubit>.value(
        value: cubit,
        child: child,
      );
    }

    setUp(() {
      repo = _FakeProviderRepository();
      cubit = ProviderCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets('renders harness model section and provider keys section',
        (tester) async {
      await tester.pumpWidget(_wrap(
        wrapWithCubit(const ProviderView()),
      ));

      cubit.watchAll();
      await tester.pumpAndSettle();

      expect(find.text('HARNESS MODELS'), findsOneWidget);
      expect(find.text('API KEYS'), findsOneWidget);
      expect(find.text('NO HARNESS MODELS LISTED'), findsOneWidget);
      expect(find.text('NO API KEYS CONFIGURED'), findsOneWidget);
    });

    testWidgets('lists harness models joined with harness/model names',
        (tester) async {
      await cubit.close();
      repo = _FakeProviderRepository(
        initialHarnesses: [testHarnesse],
        initialModels: [testModel],
        initialHarnessModels: [testHarnessModel],
      );
      cubit = ProviderCubit(repo);

      await tester.pumpWidget(_wrap(
        wrapWithCubit(const ProviderView()),
      ));

      cubit.watchAll();
      await tester.pumpAndSettle();

      expect(find.text('GOOSE'), findsOneWidget);
      expect(find.text('CLAUDE SONNET'), findsOneWidget);
      expect(find.text('[ DEFAULT ]'), findsOneWidget);
    });

    testWidgets('lists provider keys with masked env var preview',
        (tester) async {
      await cubit.close();
      repo = _FakeProviderRepository(
        initialHarnesses: [testHarnesse],
        initialProviderKeys: [testProviderKey],
      );
      cubit = ProviderCubit(repo);

      await tester.pumpWidget(_wrap(
        wrapWithCubit(const ProviderView()),
      ));

      cubit.watchAll();
      await tester.pumpAndSettle();

      expect(find.text('GOOSE'), findsWidgets);
      // 8+ char value gives the head..tail form.
      expect(find.text('sk-s..cret'), findsOneWidget);
    });

    testWidgets('shows loading indicator until data arrives', (tester) async {
      // A never-emitting repo keeps the cubit pinned in its loading state
      // deterministically (a single-yield async* stream would otherwise
      // resolve within the same pump(), racing past the loading frame).
      await cubit.close();
      repo = _FakeProviderRepository(neverEmit: true);
      cubit = ProviderCubit(repo);

      await tester.pumpWidget(_wrap(
        wrapWithCubit(const ProviderView()),
      ));

      cubit.watchAll();
      await tester.pump();

      expect(find.text('[ LOADING PROVIDERS ]'), findsOneWidget);
    });

    testWidgets('ADD KEY opens the editor dialog', (tester) async {
      await cubit.close();
      repo = _FakeProviderRepository(
        initialHarnesses: [testHarnesse],
      );
      cubit = ProviderCubit(repo);

      await tester.pumpWidget(_wrap(
        wrapWithCubit(const ProviderView()),
      ));

      cubit.watchAll();
      await tester.pumpAndSettle();

      expect(find.text('ADD KEY'), findsOneWidget);

      await tester.tap(find.text('ADD KEY'));
      await tester.pumpAndSettle();

      // The harness field's placeholder reads "SELECT PROVIDER" until a
      // harness is picked.
      expect(find.text('SELECT PROVIDER'), findsOneWidget);

      // Tap the harness field to open the nested selection dialog.
      await tester.tap(find.text('SELECT PROVIDER'));
      await tester.pumpAndSettle();

      expect(find.text('GOOSE'), findsWidgets);
      expect(find.text('goose'), findsWidgets);
    });
  });
}
