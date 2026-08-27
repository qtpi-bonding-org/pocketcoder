import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';

class HarnessAuthScreenView extends StatelessWidget {
  const HarnessAuthScreenView({
    super.key,
    required this.onboarding,
    required this.harnesses,
    required this.harnessProviders,
    required this.statuses,
    required this.error,
    required this.isLoading,
    required this.isHarnessBusy,
    required this.onStartAccount,
    required this.onStartNone,
    required this.onPoll,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
  });

  final bool onboarding;
  final List<Harnesse> harnesses;
  final List<HarnessProvider> harnessProviders;
  final Map<String, HarnessAuthStatus> statuses;
  final Object? error;
  final bool isLoading;
  final bool Function(String) isHarnessBusy;
  final Future<void> Function(Harnesse, String) onStartAccount;
  final Future<void> Function(Harnesse) onStartNone;
  final void Function(Harnesse) onPoll;
  final Future<void> Function(Harnesse, String) onSubmit;
  final void Function(Harnesse) onCancel;
  final void Function(Harnesse) onDisconnect;
  final void Function(Harnesse) onRefresh;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        title: onboarding
            ? context.l10n.onboardingChooseHarnessTitle
            : context.l10n.harnessAuthConnections,
        activePillar: NavPillar.configure,
        showBack: true,
        body: HarnessAuthView(
          onboarding: onboarding,
          harnesses: harnesses,
          harnessProviders: harnessProviders,
          statuses: statuses,
          error: error,
          isLoading: isLoading,
          isHarnessBusy: isHarnessBusy,
          onStartAccount: onStartAccount,
          onStartNone: onStartNone,
          onPoll: onPoll,
          onSubmit: onSubmit,
          onCancel: onCancel,
          onDisconnect: onDisconnect,
          onRefresh: onRefresh,
        ),
      );
}

class HarnessAuthView extends StatefulWidget {
  const HarnessAuthView({
    super.key,
    required this.onboarding,
    required this.harnesses,
    required this.harnessProviders,
    required this.statuses,
    required this.error,
    required this.isLoading,
    required this.isHarnessBusy,
    required this.onStartAccount,
    required this.onStartNone,
    required this.onPoll,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
  });
  final bool onboarding;
  final List<Harnesse> harnesses;
  final List<HarnessProvider> harnessProviders;
  final Map<String, HarnessAuthStatus> statuses;
  final Object? error;
  final bool isLoading;
  final bool Function(String) isHarnessBusy;
  final Future<void> Function(Harnesse, String) onStartAccount;
  final Future<void> Function(Harnesse) onStartNone;
  final void Function(Harnesse) onPoll;
  final Future<void> Function(Harnesse, String) onSubmit;
  final void Function(Harnesse) onCancel;
  final void Function(Harnesse) onDisconnect;
  final void Function(Harnesse) onRefresh;

  @override
  State<HarnessAuthView> createState() => _HarnessAuthViewState();
}

class _HarnessAuthViewState extends State<HarnessAuthView> {
  final Map<String, TextEditingController> _controllers = {};
  TextEditingController _controller(String id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _matches(Harnesse h) =>
      !widget.onboarding ||
      ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.harnesses.isEmpty) {
      return Center(
          child:
              TerminalLoadingIndicator(label: context.l10n.harnessAuthLoading));
    }
    final harnesses = widget.harnesses.where(_matches).toList();
    if (harnesses.isEmpty) {
      return Center(
          child: TerminalText(
              widget.onboarding
                  ? context.l10n.harnessAuthUnavailable
                  : context.l10n.harnessAuthEmpty,
              alpha: .6));
    }
    return ListView(padding: EdgeInsets.all(AppSizes.space), children: [
      if (widget.error != null)
        Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: TerminalText(safeErrorMessage(widget.error),
                color: context.terminalColors.warning, alpha: .9)),
      for (final h in harnesses)
        HarnessAuthCard(
            harness: h,
            harnessProviders: widget.harnessProviders,
            status: widget.statuses[h.id],
            codeController: _controller(h.id),
            isBusy: widget.isHarnessBusy(h.id),
            onStartAccount: (provider) => widget.onStartAccount(h, provider),
            onStartNone: () => widget.onStartNone(h),
            onPoll: () => widget.onPoll(h),
            onSubmit: (code) => widget.onSubmit(h, code),
            onCancel: () => widget.onCancel(h),
            onDisconnect: () => widget.onDisconnect(h),
            onRefresh: () => widget.onRefresh(h)),
    ]);
  }
}

class HarnessAuthCard extends StatelessWidget {
  const HarnessAuthCard(
      {super.key,
      required this.harness,
      required this.harnessProviders,
      required this.status,
        required this.codeController,
      required this.isBusy,
      required this.onStartAccount,
        required this.onStartNone,
      required this.onPoll,
      required this.onSubmit,
      required this.onCancel,
      required this.onDisconnect,
      required this.onRefresh});
  final Harnesse harness;
  final List<HarnessProvider> harnessProviders;
  final HarnessAuthStatus? status;
  final TextEditingController codeController;
  final bool isBusy;
  final void Function(String) onStartAccount;
  final VoidCallback onStartNone;
  final VoidCallback onPoll;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edges = harnessProviders.where((p) => p.harness == harness.id).toList();
    final s = status ??
        HarnessAuthStatus(
            harness: harness.id,
            provider: edges
                    .where((e) => e.supportsOauth == true)
                    .firstOrNull
                    ?.provider ??
                '',
            accountId: '',
            accountName: '',
            visibility: harnessAccountVisibilityPersonal,
            credentialMode: 'none',
            status: 'disconnected');
    return BiosSection(
        title: '${harness.name} [${harness.cliId}]',
        child: TerminalCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TerminalText(l10n.harnessAuthStatus(s.status.toUpperCase()),
                  weight: TerminalTextWeight.heavy),
              if (s.lastError case final lastError?
                  when lastError.isNotEmpty) ...[
                VSpace.x1,
                TerminalText(lastError,
                    color: context.terminalColors.warning)
              ],
              if (s.credentialMode.isNotEmpty) ...[
                VSpace.x1,
                TerminalText(
                    l10n.harnessAuthMode(s.credentialMode.toUpperCase()))
              ],
              if (s.accountId.isNotEmpty) ...[
                VSpace.x1,
                TerminalText(l10n.harnessAuthAccount(
                    s.accountName.isEmpty ? s.accountId : s.accountName,
                    s.isDeploymentVisible
                        ? l10n.harnessAuthShared
                        : l10n.harnessAuthPersonal))
              ],
              VSpace.x2,
              if (s.challenge case final challenge?)
                HarnessChallengePanel(challenge: challenge),
              if (s.challenge != null) ...[
                VSpace.x1,
                TerminalTextField(
                    controller: codeController,
                    label: l10n.harnessAuthOneTimeCode,
                    hint: l10n.harnessAuthPasteCode,
                    onSubmitted: _submit,
                    enabled: !isBusy),
                VSpace.x1,
                Align(
                    alignment: Alignment.centerRight,
                    child: TerminalButton(
                        label: l10n.harnessAuthSubmit,
                        onTap: () => _submit(codeController.text),
                        isLoading: isBusy))
              ],
              VSpace.x2,
              _actions(context, s, edges),
              VSpace.x2,
              Align(
                  alignment: Alignment.centerLeft,
                  child: TerminalButton(
                      label: l10n.harnessAuthRefresh,
                      isPrimary: false,
                      isLoading: isBusy,
                      onTap: isBusy ? () {} : onRefresh)),
              if (s.attempt case final attempt?)
                Padding(
                    padding: EdgeInsets.only(top: AppSizes.space),
                    child: TerminalText(l10n.harnessAuthAttempt(attempt.id),
                        alpha: .5)),
            ])));
  }

  Widget _actions(BuildContext context, HarnessAuthStatus s, List<HarnessProvider> edges) {
    if (s.isDisconnected) {
      return Wrap(
          spacing: AppSizes.space,
          runSpacing: AppSizes.space,
          children: [
            for (final edge in edges)
              if (edge.supportsOauth == true)
                TerminalButton(
                    label: context.l10n.harnessAuthAccountLogin,
                    onTap: isBusy ? () {} : () => onStartAccount(edge.provider),
                    isLoading: isBusy),
            TerminalButton(
                label: context.l10n.harnessAuthNone,
                onTap: isBusy ? () {} : onStartNone,
                isLoading: isBusy,
                isPrimary: false),
            TerminalButton(
                label: context.l10n.harnessAuthPoll,
                onTap: isBusy ? () {} : onPoll,
                isLoading: isBusy,
                isPrimary: false),
          ]);
    }
    if (s.isConnected) {
      return TerminalButton(
          label: context.l10n.harnessAuthDisconnect,
          onTap: isBusy ? () {} : onDisconnect,
          isLoading: isBusy);
    }
    return Wrap(spacing: AppSizes.space, runSpacing: AppSizes.space, children: [
      TerminalButton(
          label: context.l10n.harnessAuthPoll,
          onTap: isBusy ? () {} : onPoll,
          isLoading: isBusy,
          isPrimary: false),
      TerminalButton(
          label: context.l10n.harnessAuthCancel,
          onTap: isBusy ? () {} : onCancel,
          isLoading: isBusy)
    ]);
  }

  Future<void> _submit(String code) async {
    final value = code.trim();
    if (value.isEmpty || isBusy) {
      return;
    }
    await onSubmit(value);
    codeController.clear();
  }
}

class HarnessChallengePanel extends StatelessWidget {
  const HarnessChallengePanel({super.key, required this.challenge});
  final HarnessAuthChallenge challenge;
  @override
  Widget build(BuildContext context) => Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TerminalText(context.l10n.harnessAuthChallenge,
            weight: TerminalTextWeight.heavy),
        VSpace.x1,
        TerminalText(challenge.text),
        if (challenge.target case final target? when target.isNotEmpty) ...[
          VSpace.x1,
          GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: target));
                VimToast.show(
                    context, context.l10n.harnessAuthChallengeTargetCopied);
              },
              child: TerminalText(target,
                  color: Theme.of(context).colorScheme.primary, alpha: .9))
        ],
        if (challenge.details case final details? when details.isNotEmpty) ...[
          VSpace.x1,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TerminalText(
                    context.l10n.harnessAuthDetails(details), alpha: .7),
              ),
              HSpace.x1,
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: details));
                  VimToast.show(
                      context, context.l10n.harnessAuthChallengeDetailsCopied);
                },
                child: TerminalText(context.l10n.harnessAuthCopy,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ],
      ]));
}
