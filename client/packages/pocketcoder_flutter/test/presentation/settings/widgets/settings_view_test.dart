import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/settings/widgets/settings_view.dart';

void main() {
  testWidgets('Configure rows show only the label, no bracketed action word',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: SettingsView(
        hasPendingMcp: false,
        isPro: true,
        onNavigate: (_) {},
        onLogout: () {},
        onFactoryReset: () {},
        onDeleteProData: () {},
        onReportAiContent: () {},
        hapticsEnabled: true,
        onHapticsChanged: (_) {},
      ),
    ));

    expect(find.text('[SETUP]'), findsNothing);
    expect(find.text('[CONFIGURE]'), findsNothing);
    expect(find.text('[MANAGE]'), findsNothing);
    expect(find.textContaining('TOOL PERMISSIONS'), findsOneWidget);
    expect(find.textContaining('POCKETCODER UPDATE'), findsNothing,
        reason: 'promoted to the MANAGE footer button; the Configure row '
            'was a dead link before that (no instanceId reached the '
            'screen) and is redundant now');
  });

  testWidgets('REPORT AI CONTENT row is present and invokes onReportAiContent',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: SettingsView(
        hasPendingMcp: false,
        isPro: true,
        onNavigate: (_) {},
        onLogout: () {},
        onFactoryReset: () {},
        onDeleteProData: () {},
        onReportAiContent: () => tapped = true,
        hapticsEnabled: true,
        onHapticsChanged: (_) {},
      ),
    ));

    await tester.tap(find.text('REPORT AI CONTENT'));
    expect(tapped, isTrue);
  });

  testWidgets('Pro Settings row is hidden when isPro is false', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: SettingsView(
        hasPendingMcp: false,
        isPro: false,
        onNavigate: (_) {},
        onLogout: () {},
        onFactoryReset: () {},
        onDeleteProData: () {},
        onReportAiContent: () {},
        hapticsEnabled: true,
        onHapticsChanged: (_) {},
      ),
    ));

    expect(find.textContaining('PRO'), findsNothing);
  });

  testWidgets(
      'BiosSection centers its title with a divider on both sides '
      'when centerTitle is true', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BiosSection(
          title: 'security',
          centerTitle: true,
          child: SizedBox.shrink(),
        ),
      ),
    ));

    final titleRow = tester.widget<Row>(find.byType(Row).first);
    final dividerCount = titleRow.children
        .where((w) => w is Expanded && w.child is Divider)
        .length;
    expect(dividerCount, 2,
        reason:
            'centered title needs a divider on both sides, not just trailing');
  });

  testWidgets(
      'BiosSection stays left-aligned with a trailing divider only '
      'by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BiosSection(title: 'security', child: SizedBox.shrink()),
      ),
    ));

    final titleRow = tester.widget<Row>(find.byType(Row).first);
    final dividerCount = titleRow.children
        .where((w) => w is Expanded && w.child is Divider)
        .length;
    expect(dividerCount, 1,
        reason: 'default layout only has a trailing divider after the title');
  });
}
