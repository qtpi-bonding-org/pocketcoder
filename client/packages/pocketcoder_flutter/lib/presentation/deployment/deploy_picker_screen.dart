import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/deployment/deploy_picker_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'adapters/deploy_picker_adapter.dart';

class DeployPickerScreen extends StatelessWidget {
  const DeployPickerScreen({
    super.key,
    this.credentials,
    required this.deployOptionService,
    required this.onHasProAccess,
  });

  final DeployCredentials? credentials;
  final IDeployOptionService deployOptionService;
  final Future<bool> Function() onHasProAccess;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DeployPickerCubit(deployOptionService),
        child: DeployPickerAdapter(
          credentials: credentials,
          onHasProAccess: onHasProAccess,
        ),
      );
}

class DeployPickerView extends StatelessWidget {
  const DeployPickerView({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final List<DeployOption> options;
  final Future<void> Function(DeployOption option) onSelected;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        title: context.l10n.deployTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        showNavigation: false,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PocoBubble(
                    message: context.l10n.onboardingProviderPoco,
                    pocoSize: AppSizes.fontLarge,
                  ),
                  VSpace.x3,
                  TerminalText.label(context.l10n.onboardingProviderTitle),
                  VSpace.x2,
                  for (final option in options)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSizes.space),
                      child: option.isAvailable
                          ? TerminalPromptSuggestion(
                              label: option.requiresPro
                                  ? '${option.name} · ${context.l10n.deployProBadge}'
                                  : option.name,
                              onSelected: () => onSelected(option),
                            )
                          : _UnavailableProvider(option: option),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _UnavailableProvider extends StatelessWidget {
  const _UnavailableProvider({required this.option});

  final DeployOption option;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      enabled: false,
      button: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: TerminalText(
          '> ${option.name.toUpperCase()} · ${context.l10n.deployComingSoon}',
          size: TerminalTextSize.tiny,
          alpha: 0.42,
          weight: TerminalTextWeight.heavy,
        ),
      ),
    );
  }
}
