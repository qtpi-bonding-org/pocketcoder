import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/deployment/choose_provider_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/presentation/deployment/server_credentials.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'adapters/choose_provider_adapter.dart';

class ChooseProviderScreen extends StatelessWidget {
  const ChooseProviderScreen(
      {super.key,
      this.credentials,
      required this.deployOptionService,
      required this.onHasProAccess,
      this.onProviderSelected});

  final ServerCredentials? credentials;
  final IProviderOptionService deployOptionService;
  final Future<bool> Function() onHasProAccess;
  final DeployProviderSelectionHandler? onProviderSelected;

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (_) => ChooseProviderCubit(deployOptionService),
      child: ChooseProviderAdapter(
          credentials: credentials,
          onHasProAccess: onHasProAccess,
          onProviderSelected: onProviderSelected));
}

class ChooseProviderView extends StatelessWidget {
  const ChooseProviderView(
      {super.key, required this.options, required this.onSelected});

  final List<ProviderOption> options;
  final Future<void> Function(ProviderOption option) onSelected;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
      footer: buildPillarFooter(context, NavPillar.config),
      showBack: true,
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
              child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PocoBubble(
                            posture: PocoPosture.armored,
                            message: context.l10n.onboardingProviderPoco),
                        VSpace.x3,
                        TerminalText(
                          context.l10n.onboardingProviderTitle,
                          role: TextRole.body,
                        ),
                        VSpace.x2,
                        for (final option in options)
                          Padding(
                              padding: EdgeInsets.only(bottom: AppSizes.space),
                              child: option.isAvailable
                                  ? TerminalPromptSuggestion(
                                      label: option.requiresPro
                                          ? '${option.name} · ${context.l10n.chooseProviderProBadge}'
                                          : option.name,
                                      onSelected: () => onSelected(option))
                                  : _UnavailableProvider(option: option)),
                      ])))));
}

class _UnavailableProvider extends StatelessWidget {
  const _UnavailableProvider({required this.option});

  final ProviderOption option;

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
                border:
                    Border.all(color: colors.onSurface.withValues(alpha: 0.2))),
            child: TerminalText(
              '> ${option.name} · ${context.l10n.chooseProviderComingSoon}',
              role: TextRole.label,
            )));
  }
}
