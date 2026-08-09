import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class HarnessAuthorizationView extends StatefulWidget {
  const HarnessAuthorizationView({
    super.key,
    required this.harnessId,
    required this.provider,
    required this.isLoading,
    required this.harnessExists,
    required this.status,
    required this.isBusy,
    required this.onPoll,
    required this.onSubmit,
    required this.onStartLogin,
    required this.onOpenChallenge,
  });

  final String harnessId;
  final String provider;
  final bool isLoading;
  final bool harnessExists;
  final HarnessAuthStatus? status;
  final bool isBusy;
  final Future<void> Function() onPoll;
  final Future<void> Function(String code) onSubmit;
  final Future<void> Function() onStartLogin;
  final ValueChanged<HarnessAuthChallenge> onOpenChallenge;

  @override
  State<HarnessAuthorizationView> createState() =>
      _HarnessAuthorizationViewState();
}

class _HarnessAuthorizationViewState extends State<HarnessAuthorizationView> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n
          .onboardingHarnessLoginTitle(widget.provider.toUpperCase()),
      activePillar: NavPillar.configure,
      showBack: true,
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (widget.isLoading && !widget.harnessExists) {
      return const Center(child: TerminalLoadingIndicator());
    }
    if (!widget.harnessExists) {
      return Center(
          child: TerminalText(context.l10n.onboardingHarnessNotFound));
    }

    final current = widget.status ??
        const HarnessAuthStatus(
          harness: '',
          scopeKind: 'user',
          scopeId: '',
          bindingId: '',
          credentialMode: 'none',
          status: 'disconnected',
        );
    final challenge = current.challenge;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSizes.space * 2),
          child: TerminalCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    current.isConnected
                        ? context.l10n.onboardingConnected
                        : context.l10n.onboardingAccountLogin,
                    style: TextStyle(
                        color: context.colorScheme.primary,
                        fontFamily: AppFonts.headerFamily,
                        fontSize: AppSizes.fontBig,
                        fontWeight: AppFonts.heavy),
                  ),
                  VSpace.x2,
                  if (current.lastError != null) ...[
                    Text(current.lastError!,
                        style: TextStyle(color: context.colorScheme.error)),
                    VSpace.x2,
                  ],
                  if (current.isConnecting) ...[
                    TerminalText(
                        widget.provider == 'codex'
                            ? 'CODEX AUTHENTICATION IS RUNNING. CHECKING DEVICE STATUS...'
                            : 'WAITING FOR AUTHORIZATION...',
                        alpha: 0.7),
                    VSpace.x2,
                  ],
                  if (challenge != null) ...[
                    _Challenge(
                      challenge: challenge,
                      onOpen: () => widget.onOpenChallenge(challenge),
                    ),
                    VSpace.x2,
                  ],
                  if (challenge != null &&
                      widget.provider == 'claude-code') ...[
                    TerminalTextField(
                        controller: _codeController,
                        label: context.l10n.onboardingAuthorizationCode,
                        hint: context.l10n.onboardingAuthorizationCodeHint,
                        enabled: !widget.isBusy),
                    VSpace.x2,
                    TerminalButton(
                        label: context.l10n.onboardingSubmitCode,
                        isLoading: widget.isBusy,
                        onTap: () =>
                            widget.onSubmit(_codeController.text.trim())),
                  ] else if (current.isDisconnected) ...[
                    TerminalButton(
                        label: context.l10n.onboardingAccountLogin,
                        isLoading: widget.isBusy,
                        onTap: widget.onStartLogin),
                  ],
                  if (current.isConnecting &&
                      (widget.provider == 'codex' || challenge == null)) ...[
                    VSpace.x2,
                    TerminalButton(
                        label: context.l10n.onboardingCheckStatus,
                        isPrimary: false,
                        isLoading: widget.isBusy,
                        onTap: widget.onPoll),
                  ],
                  if (current.status == 'error') ...[
                    VSpace.x2,
                    TerminalButton(
                        label: context.l10n.onboardingAccountLogin,
                        isLoading: widget.isBusy,
                        onTap: widget.onStartLogin),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}

class _Challenge extends StatelessWidget {
  const _Challenge({required this.challenge, required this.onOpen});
  final HarnessAuthChallenge challenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final target = challenge.target;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TerminalText(challenge.text),
      if (target != null && target.isNotEmpty) ...[
        VSpace.x2,
        TerminalButton(
          label: context.l10n.onboardingOpenAuthorization,
          onTap: onOpen,
        ),
        VSpace.x1,
        SelectableText(target),
      ],
      if (challenge.details != null && challenge.details!.isNotEmpty) ...[
        VSpace.x1,
        TerminalText(challenge.details!, alpha: 0.7)
      ],
    ]);
  }
}
