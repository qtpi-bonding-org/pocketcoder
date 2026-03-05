import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';

/// Data-driven deploy picker screen.
///
/// Shows available deploy providers from [IDeployOptionService].
/// FOSS builds show only Hetzner. Proprietary builds add Linode + Elestio.
class DeployPickerScreen extends StatelessWidget {
  const DeployPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = GetIt.I<IDeployOptionService>().getAvailableProviders();
    final colors = context.colorScheme;

    return TerminalScaffold(
      title: 'DEPLOY POCKETCODER',
      actions: [
        TerminalAction(
          label: 'BACK',
          onTap: () => AppNavigation.back(context),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Column(
              children: [
                BiosFrame(
                  title: 'SELECT PROVIDER',
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHOOSE WHERE TO DEPLOY YOUR INSTANCE',
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                        VSpace.x3,
                        ...options.map(
                          (option) => Padding(
                            padding:
                                EdgeInsets.only(bottom: AppSizes.space),
                            child: _ProviderCard(option: option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final DeployOption option;

  const _ProviderCard({required this.option});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return InkWell(
      onTap: () => _onTap(context),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSizes.space * 1.5),
        decoration: BoxDecoration(
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              option.routePath != null
                  ? Icons.cloud_outlined
                  : Icons.open_in_new,
              color: colors.primary,
              size: 24,
            ),
            HSpace.x2,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.headerFamily,
                      color: colors.onSurface,
                      fontSize: AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  VSpace.x1,
                  Text(
                    option.description.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: AppSizes.fontTiny,
                    ),
                  ),
                ],
              ),
            ),
            if (option.requiresPurchase)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.space,
                  vertical: AppSizes.space * 0.5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.primary),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.primary,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    if (option.requiresPurchase) {
      final billing = GetIt.I<BillingService>();
      final premium = await billing.isPremium();
      if (!premium) {
        if (context.mounted) {
          AppNavigation.toPaywall(context);
        }
        return;
      }
    }

    if (option.url != null) {
      final uri = Uri.parse(option.url!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (option.routePath != null) {
      if (context.mounted) {
        context.push(option.routePath!);
      }
    }
  }
}
