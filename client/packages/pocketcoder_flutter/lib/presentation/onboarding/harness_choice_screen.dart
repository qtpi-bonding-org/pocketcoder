import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class HarnessChoiceScreen extends StatelessWidget {
  const HarnessChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProviderCubit>()..watchAll(),
      child: BlocBuilder<ProviderCubit, ProviderState>(
        builder: (context, state) {
          final harnesses = state.harnesses.where((h) {
            final cli = h.cliId.trim().toLowerCase();
            return cli == 'claude-code' || cli == 'codex';
          }).toList();

          return PocketCoderShell(
            title: context.l10n.onboardingChooseHarnessTitle,
            activePillar: NavPillar.configure,
            showBack: true,
            body: state.isLoading && harnesses.isEmpty
                ? const Center(child: TerminalLoadingIndicator())
                : state.isFailure && harnesses.isEmpty
                    ? Center(
                        child: TerminalText(
                          state.error?.toString() ?? context.l10n.errorGeneric,
                          color: context.colorScheme.error,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : harnesses.isEmpty
                        ? Center(child: TerminalText(context.l10n.errorGeneric))
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.all(AppSizes.space * 2),
                                children: [
                                  TerminalText(
                                    context.l10n.onboardingChooseHarnessBody,
                                    alpha: 0.7,
                                  ),
                                  VSpace.x3,
                                  for (final harness in harnesses)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          bottom: AppSizes.space),
                                      child:
                                          _HarnessChoiceCard(harness: harness),
                                    ),
                                ],
                              ),
                            ),
                          ),
          );
        },
      ),
    );
  }
}

class _HarnessChoiceCard extends StatelessWidget {
  const _HarnessChoiceCard({required this.harness});

  final Harnesse harness;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cli = harness.cliId.toLowerCase();
    final route = cli == 'codex'
        ? RouteNames.onboardingCodexAuth
        : RouteNames.onboardingClaudeAuth;

    return InkWell(
      onTap: () {
        OnboardingLogger.event('harness selected', {
          'harness': harness.id,
          'cli': cli,
        });
        context.pushNamed(route, extra: harness.id);
      },
      child: TerminalCard(
        child: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: colors.primary),
            HSpace.x2,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    harness.name,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: AppFonts.headerFamily,
                      fontSize: AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  VSpace.x1,
                  TerminalText(
                    cli == 'codex'
                        ? context.l10n.onboardingCodexAccountLogin
                        : context.l10n.onboardingClaudeAccountLogin,
                    alpha: 0.6,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
