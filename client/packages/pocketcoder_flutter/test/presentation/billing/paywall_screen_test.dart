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
    VoidCallback? onContinue,
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
        onContinue: onContinue,
      ),
    );
  }

  testWidgets(
      'presents the store-derived billed amount as the most conspicuous '
      'pricing element, with the trial subordinate (Guideline 3.1.2(c))',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    final billed = l10n.proPricePerMonth(r'$9.99');
    final billedFinder = find.text(billed);
    final buttonFinder = find.text('<${l10n.proSubscribePrice(billed)}>');
    final trialNote = find.text(l10n.proTrialTerms(7, billed));

    expect(billedFinder, findsOneWidget);
    expect(buttonFinder, findsOneWidget);
    expect(trialNote, findsOneWidget);
    expect(find.text(l10n.proTrialLapseExplainer), findsOneWidget);
    expect(find.text('<${l10n.proRestore}>'), findsOneWidget);

    // The button leads with the billed amount, not the trial.
    expect(find.text('<start 7-day free trial>'), findsNothing);

    // Billed amount sits above the call to action, trial note below it.
    final billedY = tester.getTopLeft(billedFinder).dy;
    final buttonY = tester.getTopLeft(buttonFinder).dy;
    final trialY = tester.getTopLeft(trialNote).dy;
    expect(billedY, lessThan(buttonY));
    expect(trialY, greaterThan(buttonY));

    // Billed amount is bold; the trial note is regular weight.
    final billedStyle = tester.widget<Text>(billedFinder).style!;
    final trialStyle = tester.widget<Text>(trialNote).style;
    expect(billedStyle.fontWeight, FontWeight.w700);
    expect(trialStyle?.fontWeight ?? FontWeight.w400, FontWeight.w400);

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
    // TerminalButton decorates every label as <label>; the call site must not.
    final terms = find.text('<${l10n.proTermsOfServiceLink}>');
    final privacy = find.text('<${l10n.proPrivacyPolicyLink}>');
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);

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

    final l10n = lookupAppLocalizations(const Locale('en'));
    final subscribe =
        find.text('<${l10n.proSubscribePrice(l10n.proPricePerMonth(r'$9.99'))}>');
    await tester.ensureVisible(subscribe);
    await tester.tap(subscribe);
    await tester.ensureVisible(find.text('<restore purchases>'));
    await tester.tap(find.text('<restore purchases>'));

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
      'an already-unlocked subscriber sees a continue affordance only when '
      'onContinue is supplied, and tapping it invokes the callback',
      (tester) async {
    var continues = 0;
    await tester.pumpWidget(subject(
      state: const BillingState(package: package, isPro: true),
      onContinue: () => continues += 1,
    ));
    await tester.pumpAndSettle();

    expect(find.text('<continue setup>'), findsOneWidget);
    await tester.tap(find.text('<continue setup>'));
    expect(continues, 1);
  });

  testWidgets(
      'an already-unlocked subscriber outside guided setup sees no '
      'continue affordance', (tester) async {
    await tester.pumpWidget(subject(
      state: const BillingState(package: package, isPro: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('<continue setup>'), findsNothing);
  });

  testWidgets(
      'keeps only the back action, whether reached during '
      'onboarding or standalone from Configure', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFooter), findsOneWidget);
    expect(find.text('back'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    expect(find.text('status'), findsNothing);
    expect(find.text('config'), findsNothing);
    expect(find.text('control'), findsNothing);
  });
}
