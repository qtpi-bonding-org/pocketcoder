import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// Data-driven deploy picker screen.
///
/// Shows available deploy providers from [IDeployOptionService].
/// FOSS builds show only Hetzner. Proprietary builds add Linode + Elestio.
class DeployPickerScreen extends StatelessWidget {
  const DeployPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = GetIt.I<IDeployOptionService>().getAvailableProviders();

    return PocketCoderShell(
      title: context.l10n.deployTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Column(
              children: [
                BiosFrame(
                  title: context.l10n.deploySelectProvider,
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TerminalText(
                          context.l10n.deployChooseProvider,
                          alpha: 0.7,
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
                  TerminalText.tiny(
                    option.description.toUpperCase(),
                    alpha: 0.6,
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
                child: TerminalText(
                  context.l10n.deployProBadge,
                  size: TerminalTextSize.tiny,
                  weight: TerminalTextWeight.heavy,
                  color: colors.primary,
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
      final hasAccess = await billing.hasDeployAccess();
      if (!hasAccess) {
        final purchased = await billing.purchase('pocketcoder_deploy_24h');
        if (!purchased) return;
      }
    }

    final url = option.url;
    final routePath = option.routePath;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else if (routePath != null) {
      if (context.mounted) {
        context.push(routePath);
      }
    }
  }
}
