import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders as an expand-variant DetailRow', (tester) async {
    const provider =
        domain.Provider(id: 'p1', providerId: 'claude', name: 'Claude');
    await tester.pumpWidget(_app(ProviderTargetPicker(
      targets: const [provider],
      selectedProvider: provider,
      onSelected: (_) {},
    )));

    expect(find.byType(DetailRow), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);
  });

  testWidgets('search box filters a large synced provider list client-side',
      (tester) async {
    // The provider list is now synced in full from models.dev (no
    // PocketCoder-side curation), so it can run to ~200 entries -- the
    // picker dialog must let the user filter it rather than dumping an
    // unsearchable list.
    final targets = [
      const domain.Provider(
        id: 'p1',
        providerId: 'anthropic',
        name: 'Anthropic',
      ),
      const domain.Provider(
        id: 'p2',
        providerId: 'openai',
        name: 'OpenAI',
      ),
      const domain.Provider(
        id: 'p3',
        providerId: 'openrouter',
        name: 'OpenRouter',
      ),
    ];
    domain.Provider? picked;
    await tester.pumpWidget(_app(ProviderTargetPicker(
      targets: targets,
      selectedProvider: null,
      onSelected: (t) => picked = t,
    )));

    await tester.tap(find.byType(DetailRow));
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsOneWidget);
    expect(find.text('OPENAI'), findsOneWidget);
    expect(find.text('OPENROUTER'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'open');
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsNothing);
    expect(find.text('OPENAI'), findsOneWidget);
    expect(find.text('OPENROUTER'), findsOneWidget);

    await tester.tap(find.text('OPENAI'));
    await tester.pumpAndSettle();

    expect(picked, targets[1]);
  });

  testWidgets('search box with no matches shows an empty-state message',
      (tester) async {
    const provider =
        domain.Provider(id: 'p1', providerId: 'claude', name: 'Claude');
    await tester.pumpWidget(_app(ProviderTargetPicker(
      targets: const [provider],
      selectedProvider: null,
      onSelected: (_) {},
    )));

    await tester.tap(find.byType(DetailRow));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nonexistent-xyz');
    await tester.pumpAndSettle();

    expect(find.text('CLAUDE'), findsNothing);
    expect(find.text('NO MATCHING PROVIDERS'), findsOneWidget);
  });
}
