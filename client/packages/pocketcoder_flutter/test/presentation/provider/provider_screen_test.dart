import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/provider/adapters/provider_adapter.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  final harness = Harnesse(id: 'h-1', name: 'Goose', cliId: 'goose', acpTransport: HarnesseAcpTransport.websocket);
  final model = Model(id: 'm-1', name: 'sonnet', displayName: 'Claude Sonnet', provider: 'anthropic');
  final harnessModel = HarnessModel(id: 'hm-1', harness: 'h-1', model: 'm-1', harnessModelId: 'goose::sonnet', isDefault: true);
  final key = ProviderKey(id: 'pk-1', user: 'u-1', provider: 'goose', envVars: <String, dynamic>{'API_KEY': 'sk-supersecret'});

  Future<void> pumpView(WidgetTester tester, {ProviderState state = const ProviderState(), Future<void> Function(ProviderKey)? onSave, Future<void> Function(String)? onDelete}) async {
    await tester.pumpWidget(_wrap(ProviderView(state: state, onSave: onSave ?? (_) async {}, onDelete: onDelete ?? (_) async {})));
    await tester.pumpAndSettle();
  }

  testWidgets('renders sections and empty states', (tester) async {
    await pumpView(tester);
    expect(find.text('HARNESS MODELS'), findsOneWidget);
    expect(find.text('API KEYS'), findsOneWidget);
    expect(find.text('NO HARNESS MODELS LISTED'), findsOneWidget);
    expect(find.text('NO API KEYS CONFIGURED'), findsOneWidget);
  });

  testWidgets('lists joined harness/model names', (tester) async {
    await pumpView(tester, state: ProviderState(harnesses: [harness], models: [model], harnessModels: [harnessModel]));
    expect(find.text('GOOSE'), findsOneWidget);
    expect(find.text('CLAUDE SONNET'), findsOneWidget);
    expect(find.text('[ DEFAULT ]'), findsOneWidget);
  });

  testWidgets('lists provider keys with masked preview', (tester) async {
    await pumpView(tester, state: ProviderState(harnesses: [harness], providerKeys: [key]));
    expect(find.text('sk-s..cret'), findsOneWidget);
  });

  testWidgets('shows loading state', (tester) async {
    await pumpView(tester, state: const ProviderState(status: UiFlowStatus.loading));
    expect(find.text('[ LOADING PROVIDERS ]'), findsOneWidget);
  });

  testWidgets('ADD KEY opens editor', (tester) async {
    await pumpView(tester, state: ProviderState(harnesses: [harness]));
    await tester.tap(find.text('ADD KEY'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT PROVIDER'), findsOneWidget);
    await tester.tap(find.text('SELECT PROVIDER'));
    await tester.pumpAndSettle();
    expect(find.text('GOOSE'), findsWidgets);
    expect(find.text('goose'), findsWidgets);
  });
}
