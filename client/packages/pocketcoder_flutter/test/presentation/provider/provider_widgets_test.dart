import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders as an expand-variant BiosRow', (tester) async {
    const harness = Harnesse(
      id: 'h1',
      name: 'Claude',
      cliId: 'claude',
      acpTransport: HarnesseAcpTransport.unknown,
    );
    await tester.pumpWidget(_app(ProviderTargetPicker(
      targets: const [HarnessKeyTarget(harness)],
      selectedProvider: 'claude',
      onSelected: (_) {},
    )));

    expect(find.byType(BiosRow), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);
  });
}
