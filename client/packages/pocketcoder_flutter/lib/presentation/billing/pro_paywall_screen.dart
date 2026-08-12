import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/presentation/billing/adapters/pro_paywall_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ProPaywallRouteArguments {
  const ProPaywallRouteArguments({this.returnOnUnlock = false});

  final bool returnOnUnlock;
}

class ProPaywallScreen extends StatelessWidget {
  const ProPaywallScreen({super.key, this.returnOnUnlock = false});

  final bool returnOnUnlock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BillingCubit>()..loadOffering(),
      child: ProPaywallAdapter(
        returnOnUnlock: returnOnUnlock,
        onConfigureSelfHostedPush: getIt<PushService>().configure,
      ),
    );
  }
}

class ProPaywallView extends StatelessWidget {
  const ProPaywallView({
    super.key,
    required this.state,
    required this.onPurchase,
    required this.onRestore,
    required this.onConfigureSelfHostedPush,
  });

  final BillingState state;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onConfigureSelfHostedPush;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.proTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
          child: BiosFrame(
            title: context.l10n.proPlanTitle,
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (state.isLoading) {
      return TerminalLoadingIndicator(label: context.l10n.proCheckingStatus);
    }
    if (state.isPro) return _ActiveProStatus(onRestore: onRestore);

    final package = state.package;
    if (package == null) {
      return _UnavailableProOffer(
        onRestore: onRestore,
        onConfigureSelfHostedPush: onConfigureSelfHostedPush,
      );
    }

    return _ProOffer(
      package: package,
      onPurchase: onPurchase,
      onRestore: onRestore,
      onConfigureSelfHostedPush: onConfigureSelfHostedPush,
    );
  }
}

class _ProOffer extends StatelessWidget {
  const _ProOffer({
    required this.package,
    required this.onPurchase,
    required this.onRestore,
    required this.onConfigureSelfHostedPush,
  });

  final BillingPackage package;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onConfigureSelfHostedPush;

  @override
  Widget build(BuildContext context) {
    final trialDays = package.freeTrialDays;
    final recurringPrice = _recurringPrice(context, package);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText(
          context.l10n.proUnlockCommand,
          size: TerminalTextSize.base,
          weight: TerminalTextWeight.heavy,
          color: context.colorScheme.primary,
        ),
        VSpace.x2,
        TerminalText(context.l10n.proSummary, alpha: 0.8),
        VSpace.x3,
        _ProFeature(label: context.l10n.proFeatureDeploy),
        _ProFeature(label: context.l10n.proFeaturePush),
        _ProFeature(label: context.l10n.proFeatureConsole),
        VSpace.x3,
        if (trialDays != null) ...[
          TerminalText(
            context.l10n.proTrialDuration(trialDays),
            size: TerminalTextSize.large,
            weight: TerminalTextWeight.heavy,
            color: context.colorScheme.primary,
          ),
          VSpace.x1,
        ],
        TerminalText(
          trialDays == null
              ? context.l10n.proPrice(recurringPrice)
              : context.l10n.proPriceAfterTrial(recurringPrice),
          weight: TerminalTextWeight.heavy,
        ),
        VSpace.x3,
        TerminalButton(
          label: trialDays == null
              ? context.l10n.proSubscribe
              : context.l10n.proStartTrial(trialDays),
          onTap: onPurchase,
        ),
        VSpace.x2,
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
        VSpace.x3,
        _SelfHostedPushOption(onConfigure: onConfigureSelfHostedPush),
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

class _ProFeature extends StatelessWidget {
  const _ProFeature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerminalText.label(
            context.l10n.proFeatureReady,
            color: context.colorScheme.primary,
          ),
          HSpace.x1,
          Expanded(child: TerminalText(label)),
        ],
      ),
    );
  }
}

class _ActiveProStatus extends StatelessWidget {
  const _ActiveProStatus({required this.onRestore});

  final VoidCallback onRestore;

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
          label: context.l10n.proRestore,
          onTap: onRestore,
          isPrimary: false,
        ),
      ],
    );
  }
}

class _UnavailableProOffer extends StatelessWidget {
  const _UnavailableProOffer({
    required this.onRestore,
    required this.onConfigureSelfHostedPush,
  });

  final VoidCallback onRestore;
  final VoidCallback onConfigureSelfHostedPush;

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
        VSpace.x3,
        _SelfHostedPushOption(onConfigure: onConfigureSelfHostedPush),
      ],
    );
  }
}

class _SelfHostedPushOption extends StatelessWidget {
  const _SelfHostedPushOption({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.all(AppSizes.space * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText.label(context.l10n.proSelfHostedPushTitle),
          VSpace.x1,
          TerminalText.mini(
            context.l10n.proSelfHostedPushBody,
            alpha: 0.75,
          ),
          VSpace.x2,
          TerminalButton(
            label: context.l10n.proConfigureSelfHostedPush,
            onTap: onConfigure,
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}
