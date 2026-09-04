import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/tinted_alert_card.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders both eyebrow labels and the child', (tester) async {
    await tester.pumpWidget(
      _app(
        const TintedAlertCard(
          eyebrowLeft: 'SECURITY',
          eyebrowRight: "COMMANDER'S SIGNOFF",
          tint: Color(0xFFFFB100),
          child: Text('body'),
        ),
      ),
    );

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text("COMMANDER'S SIGNOFF"), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('applies the supplied tint to its decoration', (tester) async {
    const tint = Color(0xFFFFB100);
    await tester.pumpWidget(
      _app(
        const TintedAlertCard(
          eyebrowLeft: 'A',
          eyebrowRight: 'B',
          tint: tint,
          child: SizedBox.shrink(),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TintedAlertCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border!.top.color.toARGB32() & 0x00FFFFFF,
        tint.toARGB32() & 0x00FFFFFF);
  });
}
