import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/billing/pro_paywall_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  const package = BillingPackage(
    identifier: 'pro-monthly',
    title: 'PocketCoder Pro',
    description: 'Every Pro capability',
    priceString: r'$9.99',
    billingPeriod: BillingPeriod.month,
    freeTrialDays: 7,
  );

  Widget subject({
    BillingState state = const BillingState(package: package),
    VoidCallback? onPurchase,
    VoidCallback? onRestore,
    VoidCallback? onConfigure,
    bool showNavigation = true,
    bool isOnboarding = false,
  }) {
    return MaterialApp(
      theme: AppTheme.terminalTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProPaywallView(
        state: state,
        onPurchase: onPurchase ?? () {},
        onRestore: onRestore ?? () {},
        onConfigureSelfHostedPush: onConfigure ?? () {},
        showNavigation: showNavigation,
        isOnboarding: isOnboarding,
      ),
    );
  }

  testWidgets('presents one Pro plan with store-derived trial and price',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('7 DAYS FREE'), findsOneWidget);
    expect(find.text(AppAscii.pocketCoderProLogo), findsOneWidget);
    expect(find.text(r'THEN $9.99 / MONTH'), findsOneWidget);
    expect(
      find.text('PROVISION AND DEPLOY POCKETCODER SERVERS'),
      findsOneWidget,
    );
    expect(find.text('RECEIVE HOSTED AGENT NOTIFICATIONS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes purchase, restore, and self-hosted callbacks',
      (tester) async {
    var purchases = 0;
    var restores = 0;
    var configures = 0;
    await tester.pumpWidget(subject(
      onPurchase: () => purchases += 1,
      onRestore: () => restores += 1,
      onConfigure: () => configures += 1,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START 7-DAY FREE TRIAL'));
    await tester.tap(find.text('START 7-DAY FREE TRIAL'));
    await tester.ensureVisible(find.text('RESTORE PURCHASES'));
    await tester.tap(find.text('RESTORE PURCHASES'));
    await tester.ensureVisible(find.text('CONFIGURE SELF-HOSTED PUSH'));
    await tester.tap(find.text('CONFIGURE SELF-HOSTED PUSH'));

    expect(purchases, 1);
    expect(restores, 1);
    expect(configures, 1);
  });

  testWidgets('keeps only the back action inside the deployment flow',
      (tester) async {
    await tester.pumpWidget(subject(
      showNavigation: false,
      isOnboarding: true,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFooter), findsOneWidget);
    expect(find.text('NOT NOW'), findsOneWidget);
    expect(find.text('CHATS'), findsNothing);
    expect(find.text('MONITOR'), findsNothing);
    expect(find.text('CONFIGURE'), findsNothing);
    expect(find.text('CONFIGURE SELF-HOSTED PUSH'), findsNothing);
  });
}
