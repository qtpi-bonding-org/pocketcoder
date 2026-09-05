import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/billing/widgets/pro_benefits_list.dart';

class ProOffer extends StatelessWidget {
  const ProOffer(
      {super.key,
      required this.package,
      required this.onPurchase,
      required this.onRestore,
      required this.onOpenTermsOfService,
      required this.onOpenPrivacyPolicy});

  final BillingPackage package;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onOpenTermsOfService;
  final VoidCallback onOpenPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final trialDays = package.freeTrialDays;
    final recurringPrice = _recurringPrice(context, package);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AsciiLogo(
          text: AppAscii.pocketCoderProLogo,
          color: context.colorScheme.primary,
          alignment: Alignment.center),
      VSpace.x3,
      const ProBenefitsList(),
      VSpace.x3,
      if (trialDays != null) ...[
        TerminalText(
          context.l10n.proTrialNoPaymentInfo,
          role: TextRole.body,
        ),
        VSpace.x1,
        TerminalText(
          context.l10n.proTrialLapseExplainer,
          role: TextRole.body,
        ),
      ],
      VSpace.x3,
      TerminalButton(
          label: trialDays == null
              ? context.l10n.proSubscribe
              : context.l10n.proStartTrial(trialDays),
          onTap: onPurchase),
      VSpace.x1,
      Center(
          child: TerminalButton(
              label: context.l10n.proRestore,
              kind: ActionKind.neutral,
              onTap: onRestore)),
      TerminalText(
        trialDays == null
            ? context.l10n.proTerms(recurringPrice)
            : context.l10n.proTrialTerms(trialDays, recurringPrice),
        role: TextRole.label,
        textAlign: TextAlign.center,
      ),
      Wrap(alignment: WrapAlignment.center, children: [
        TextButton(
            onPressed: onOpenTermsOfService,
            child: Text(context.l10n.proTermsOfServiceLink)),
        TextButton(
            onPressed: onOpenPrivacyPolicy,
            child: Text(context.l10n.proPrivacyPolicyLink)),
      ]),
    ]);
  }

  String _recurringPrice(BuildContext context, BillingPackage package) {
    return switch (package.billingPeriod) {
      BillingPeriod.week => context.l10n.proPricePerWeek(package.priceString),
      BillingPeriod.month => context.l10n.proPricePerMonth(package.priceString),
      BillingPeriod.year => context.l10n.proPricePerYear(package.priceString),
      BillingPeriod.unknown => package.priceString
    };
  }
}
