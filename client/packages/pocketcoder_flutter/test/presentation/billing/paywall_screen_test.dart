import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/billing/paywall_screen.dart';
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
    VoidCallback? onManageSubscription,
    VoidCallback? onOpenTermsOfService,
    VoidCallback? onOpenPrivacyPolicy,
  }) {
    return MaterialApp(
      theme: AppTheme.terminalTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PaywallView(
        state: state,
        onPurchase: onPurchase ?? () {},
        onRestore: onRestore ?? () {},
        onManageSubscription: onManageSubscription ?? () {},
        onOpenTermsOfService: onOpenTermsOfService ?? () {},
        onOpenPrivacyPolicy: onOpenPrivacyPolicy ?? () {},
      ),
    );
  }

  testWidgets(
      'presents the trial offer and store-derived price for a '
      'trial-eligible package', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.proTrialNoPaymentInfo), findsOneWidget);
    expect(find.text(l10n.proTrialLapseExplainer), findsOneWidget);
    expect(
        find.text('<${l10n.proStartTrial(7).toLowerCase()}>'), findsOneWidget);
    expect(find.text(l10n.proRestore), findsOneWidget);
    // Apple requires the auto-renewal disclosure visible for a trial offer
    // too, not just a plain subscription -- the trial-specific wording,
    // not the no-trial one.
    expect(
      find.text(l10n.proTrialTerms(7, l10n.proPricePerMonth(r'$9.99'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows Terms of Service and Privacy Policy links on the purchase '
      'screen, and taps invoke their callbacks', (tester) async {
    var termsOpened = 0;
    var privacyOpened = 0;
    await tester.pumpWidget(subject(
      onOpenTermsOfService: () => termsOpened += 1,
      onOpenPrivacyPolicy: () => privacyOpened += 1,
    ));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.ensureVisible(find.text(l10n.proTermsOfServiceLink));
    await tester.tap(find.text(l10n.proTermsOfServiceLink));
    await tester.ensureVisible(find.text(l10n.proPrivacyPolicyLink));
    await tester.tap(find.text(l10n.proPrivacyPolicyLink));

    expect(termsOpened, 1);
    expect(privacyOpened, 1);
  });

  testWidgets('invokes purchase and restore callbacks', (tester) async {
    var purchases = 0;
    var restores = 0;
    await tester.pumpWidget(subject(
      onPurchase: () => purchases += 1,
      onRestore: () => restores += 1,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('<start 7-day free trial>'));
    await tester.tap(find.text('<start 7-day free trial>'));
    await tester.ensureVisible(find.text('RESTORE PURCHASES'));
    await tester.tap(find.text('RESTORE PURCHASES'));

    expect(purchases, 1);
    expect(restores, 1);
  });

  testWidgets('an active Pro subscriber sees and can tap Manage Subscription',
      (tester) async {
    var manageCalls = 0;
    await tester.pumpWidget(subject(
      state: const BillingState(package: package, isPro: true),
      onManageSubscription: () => manageCalls += 1,
    ));
    await tester.pumpAndSettle();

    expect(find.text('<manage subscription>'), findsOneWidget);
    await tester.tap(find.text('<manage subscription>'));

    expect(manageCalls, 1);
  });

  testWidgets(
      'keeps only the back action, whether reached during '
      'onboarding or standalone from Configure', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFooter), findsOneWidget);
    expect(find.text('<back>'), findsOneWidget);
    expect(find.text('<chat>'), findsNothing);
    expect(find.text('<status>'), findsNothing);
    expect(find.text('<config>'), findsNothing);
    expect(find.text('<control>'), findsNothing);
  });
}
