import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/presentation/billing/adapters/paywall_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

// Apple requires these linked directly on the purchase screen itself, not
// just reachable from elsewhere in the app.
final Uri _termsOfServiceUri = Uri.parse('https://pocketcoder.org/terms');
final Uri _privacyPolicyUri = Uri.parse('https://pocketcoder.org/privacy');

class ProPaywallRouteArguments {
  const ProPaywallRouteArguments({this.returnOnUnlock = false});

  final bool returnOnUnlock;
}

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.returnOnUnlock = false});

  final bool returnOnUnlock;

  @override
  Widget build(BuildContext context) {
    final launcher = getIt<InAppBrowserLauncher>();
    return BlocProvider(
      create: (_) => getIt<BillingCubit>()..loadOffering(),
      child: ProPaywallAdapter(
        returnOnUnlock: returnOnUnlock,
        onOpenTermsOfService: () => launcher.open(_termsOfServiceUri),
        onOpenPrivacyPolicy: () => launcher.open(_privacyPolicyUri),
      ),
    );
  }
}

class PaywallView extends StatelessWidget {
  const PaywallView({
    super.key,
    required this.state,
    required this.onPurchase,
    required this.onRestore,
    required this.onManageSubscription,
    required this.onOpenTermsOfService,
    required this.onOpenPrivacyPolicy,
  });

  final BillingState state;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;
  final VoidCallback onOpenTermsOfService;
  final VoidCallback onOpenPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.proTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: BiosFrame(
              title: context.l10n.proPlanTitle,
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (state.isLoading) {
      return TerminalLoadingIndicator(label: context.l10n.proCheckingStatus);
    }
    if (state.isPro) {
      return _ActiveProStatus(
        onRestore: onRestore,
        onManageSubscription: onManageSubscription,
      );
    }

    final package = state.package;
    if (package == null) {
      return _UnavailableProOffer(onRestore: onRestore);
    }

    return _ProOffer(
      package: package,
      onPurchase: onPurchase,
      onRestore: onRestore,
      onOpenTermsOfService: onOpenTermsOfService,
      onOpenPrivacyPolicy: onOpenPrivacyPolicy,
    );
  }
}

class _ProOffer extends StatelessWidget {
  const _ProOffer({
    required this.package,
    required this.onPurchase,
    required this.onRestore,
    required this.onOpenTermsOfService,
    required this.onOpenPrivacyPolicy,
  });

  final BillingPackage package;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onOpenTermsOfService;
  final VoidCallback onOpenPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final trialDays = package.freeTrialDays;
    final recurringPrice = _recurringPrice(context, package);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AsciiLogo(
          text: AppAscii.pocketCoderProLogo,
          color: context.colorScheme.primary,
          fontSize: AppSizes.fontTiny,
          alignment: Alignment.center,
        ),
        VSpace.x3,
        const _ProBenefitsList(),
        VSpace.x3,
        if (trialDays != null) ...[
          TerminalText(
            context.l10n.proTrialNoPaymentInfo,
            size: TerminalTextSize.base,
            weight: TerminalTextWeight.heavy,
            color: context.colorScheme.primary,
          ),
          VSpace.x1,
          TerminalText(
            context.l10n.proTrialLapseExplainer,
            alpha: 0.8,
          ),
        ],
        VSpace.x3,
        TerminalButton(
          label: trialDays == null
              ? context.l10n.proSubscribe
              : context.l10n.proStartTrial(trialDays),
          onTap: onPurchase,
        ),
        VSpace.x1,
        Center(
          child: TextButton(
            onPressed: onRestore,
            child: Text(context.l10n.proRestore),
          ),
        ),
        TerminalText.tiny(
          trialDays == null
              ? context.l10n.proTerms(recurringPrice)
              : context.l10n.proTrialTerms(trialDays, recurringPrice),
          alpha: 0.65,
          textAlign: TextAlign.center,
          height: 1.4,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: onOpenTermsOfService,
              child: Text(context.l10n.proTermsOfServiceLink),
            ),
            TextButton(
              onPressed: onOpenPrivacyPolicy,
              child: Text(context.l10n.proPrivacyPolicyLink),
            ),
          ],
        ),
      ],
    );
  }

  String _recurringPrice(BuildContext context, BillingPackage package) {
    return switch (package.billingPeriod) {
      BillingPeriod.week => context.l10n.proPricePerWeek(package.priceString),
      BillingPeriod.month => context.l10n.proPricePerMonth(package.priceString),
      BillingPeriod.year => context.l10n.proPricePerYear(package.priceString),
      BillingPeriod.unknown => package.priceString,
    };
  }
}

class _ActiveProStatus extends StatelessWidget {
  const _ActiveProStatus({
    required this.onRestore,
    required this.onManageSubscription,
  });

  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText(
          context.l10n.proActive,
          size: TerminalTextSize.base,
          weight: TerminalTextWeight.heavy,
          color: context.colorScheme.primary,
        ),
        VSpace.x2,
        TerminalText(context.l10n.proActiveBody),
        VSpace.x3,
        TerminalButton(
          label: context.l10n.proManageSubscription,
          onTap: onManageSubscription,
          isPrimary: false,
        ),
        VSpace.x1,
        TerminalButton(
          label: context.l10n.proRestore,
          onTap: onRestore,
          isPrimary: false,
        ),
      ],
    );
  }
}

class _UnavailableProOffer extends StatelessWidget {
  const _UnavailableProOffer({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.label(
          context.l10n.proUnavailable,
          color: context.terminalColors.warning,
        ),
        VSpace.x2,
        TerminalText(context.l10n.proUnavailableBody),
        VSpace.x3,
        TerminalButton(
          label: context.l10n.proRestore,
          onTap: onRestore,
          isPrimary: false,
        ),
      ],
    );
  }
}

class _ProBenefitsList extends StatelessWidget {
  const _ProBenefitsList();

  @override
  Widget build(BuildContext context) {
    final benefits = [
      context.l10n.proBenefitServerSetup,
      context.l10n.proBenefitPushNotifications,
      context.l10n.proBenefitLiveMonitoring,
    ];
    return TerminalCard(
      padding: EdgeInsets.all(AppSizes.space * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final benefit in benefits)
            Padding(
              padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
              child: TerminalText.mini('> $benefit'),
            ),
        ],
      ),
    );
  }
}
