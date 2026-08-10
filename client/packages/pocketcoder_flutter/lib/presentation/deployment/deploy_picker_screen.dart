import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/deployment/deploy_picker_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'adapters/deploy_picker_adapter.dart';

class DeployPickerScreen extends StatelessWidget {
  const DeployPickerScreen({
    super.key,
    this.credentials,
    required this.deployOptionService,
    required this.onEnsureDeployAccess,
  });

  final DeployCredentials? credentials;
  final IDeployOptionService deployOptionService;
  final Future<bool> Function(String productId) onEnsureDeployAccess;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DeployPickerCubit(deployOptionService),
        child: DeployPickerAdapter(
          credentials: credentials,
          onEnsureDeployAccess: onEnsureDeployAccess,
        ),
      );
}

class DeployPickerView extends StatelessWidget {
  const DeployPickerView(
      {super.key,
      required this.options,
      this.credentials,
      required this.onSelected});

  final List<DeployOption> options;
  final DeployCredentials? credentials;
  final Future<void> Function(DeployOption option) onSelected;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        title: context.l10n.deployTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space),
              child: BiosFrame(
                title: context.l10n.deploySelectProvider,
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TerminalText(context.l10n.deployChooseProvider,
                          alpha: 0.7),
                      VSpace.x3,
                      ...options.map((option) => Padding(
                            padding: EdgeInsets.only(bottom: AppSizes.space),
                            child: _ProviderCard(
                                option: option,
                                onTap: () => onSelected(option)),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.option, required this.onTap});
  final DeployOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final isAvailable = option.isAvailable;
    return Semantics(
      enabled: isAvailable,
      button: true,
      child: Opacity(
        opacity: isAvailable ? 1 : 0.42,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSizes.space * 1.5),
            decoration: BoxDecoration(
                border:
                    Border.all(color: colors.onSurface.withValues(alpha: 0.2))),
            child: Row(children: [
              Icon(
                  option.routePath != null
                      ? Icons.cloud_outlined
                      : Icons.open_in_new,
                  color: colors.primary,
                  size: 24),
              HSpace.x2,
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(option.name.toUpperCase(),
                        style: TextStyle(
                            fontFamily: AppFonts.headerFamily,
                            color: colors.onSurface,
                            fontSize: AppSizes.fontStandard,
                            fontWeight: AppFonts.heavy)),
                    VSpace.x1,
                    TerminalText.tiny(option.description.toUpperCase(),
                        alpha: 0.6),
                  ])),
              if (option.requiresPurchase)
                Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.space,
                        vertical: AppSizes.space * .5),
                    decoration: BoxDecoration(
                        border: Border.all(color: colors.primary)),
                    child: TerminalText(context.l10n.deployProBadge,
                        size: TerminalTextSize.tiny,
                        weight: TerminalTextWeight.heavy,
                        color: colors.primary)),
              if (option.availability == DeployOptionAvailability.comingSoon)
                Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.space,
                        vertical: AppSizes.space * .5),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: colors.onSurface.withValues(alpha: 0.5))),
                    child: TerminalText(context.l10n.deployComingSoon,
                        size: TerminalTextSize.tiny,
                        weight: TerminalTextWeight.heavy,
                        color: colors.onSurface)),
            ]),
          ),
        ),
      ),
    );
  }
}
