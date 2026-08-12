import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/billing/pro_paywall_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;

const _monthlyPro = BillingPackage(
  identifier: 'pocketcoder_pro_monthly',
  title: 'PocketCoder Pro',
  description: 'One subscription. Every Pro capability.',
  priceString: r'$9.99',
  billingPeriod: BillingPeriod.month,
  freeTrialDays: 7,
);

Widget _paywall(BillingState state) => MaterialApp(
      theme: AppTheme.terminalTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProPaywallView(
        state: state,
        onPurchase: () {},
        onRestore: () {},
        onConfigureSelfHostedPush: () {},
      ),
    );

@wb.UseCase(name: '7-day trial', type: ProPaywallView)
Widget proPaywallTrial(BuildContext context) => _paywall(
      const BillingState(package: _monthlyPro),
    );

@wb.UseCase(name: 'active', type: ProPaywallView)
Widget proPaywallActive(BuildContext context) => _paywall(
      const BillingState(isPro: true),
    );

@wb.UseCase(name: 'store unavailable', type: ProPaywallView)
Widget proPaywallUnavailable(BuildContext context) => _paywall(
      const BillingState(),
    );

@wb.UseCase(name: 'loading', type: ProPaywallView)
Widget proPaywallLoading(BuildContext context) => _paywall(
      const BillingState(status: UiFlowStatus.loading),
    );
