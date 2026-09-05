import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/billing/adapters/paywall_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/billing/widgets/active_pro_status.dart';
import 'package:pocketcoder_flutter/presentation/billing/widgets/pro_offer.dart';
import 'package:pocketcoder_flutter/presentation/billing/widgets/unavailable_pro_offer.dart';

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
      footer: buildPillarFooter(context, NavPillar.config),
      showBack: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.line),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContent(context),
              ],
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
      return ActiveProStatus(
        onRestore: onRestore,
        onManageSubscription: onManageSubscription,
      );
    }

    final package = state.package;
    if (package == null) {
      return UnavailableProOffer(onRestore: onRestore);
    }

    return ProOffer(
      package: package,
      onPurchase: onPurchase,
      onRestore: onRestore,
      onOpenTermsOfService: onOpenTermsOfService,
      onOpenPrivacyPolicy: onOpenPrivacyPolicy,
    );
  }
}
