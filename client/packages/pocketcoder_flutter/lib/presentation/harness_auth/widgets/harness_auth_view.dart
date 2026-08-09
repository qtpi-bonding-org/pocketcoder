import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';

class HarnessAuthView extends StatefulWidget {
  const HarnessAuthView({super.key, required this.onboarding, required this.harnesses,
    required this.providerKeys, required this.statuses, required this.error,
    required this.isLoading, required this.isHarnessBusy, required this.onStartAccount,
    required this.onStartApiKey, required this.onStartNone, required this.onPoll,
    required this.onSubmit, required this.onCancel, required this.onDisconnect,
    required this.onRefresh,});
  final bool onboarding;
  final List<Harnesse> harnesses;
  final List<ProviderKey> providerKeys;
  final Map<String, HarnessAuthStatus> statuses;
  final Object? error;
  final bool isLoading;
  final bool Function(String) isHarnessBusy;
  final void Function(Harnesse) onStartAccount;
  final Future<void> Function(Harnesse) onStartApiKey;
  final void Function(Harnesse) onStartNone;
  final void Function(Harnesse) onPoll;
  final Future<void> Function(Harnesse, String) onSubmit;
  final void Function(Harnesse) onCancel;
  final void Function(Harnesse) onDisconnect;
  final void Function(Harnesse) onRefresh;

  @override State<HarnessAuthView> createState() => _HarnessAuthViewState();
}

class _HarnessAuthViewState extends State<HarnessAuthView> {
  final Map<String, TextEditingController> _controllers = {};
  TextEditingController _controller(String id) => _controllers.putIfAbsent(id, TextEditingController.new);
  @override void dispose() { for (final c in _controllers.values) { c.dispose(); } super.dispose(); }
  bool _matches(Harnesse h) => !widget.onboarding || ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase());

  @override Widget build(BuildContext context) {
    if (widget.isLoading && widget.harnesses.isEmpty) return const Center(child: TerminalLoadingIndicator(label: 'Loading harnesses'));
    final harnesses = widget.harnesses.where(_matches).toList();
    if (harnesses.isEmpty) return Center(child: TerminalText(widget.onboarding ? 'Claude Code and Codex are not available on this server.' : 'No harnesses were found.', alpha: .6));
    return ListView(padding: EdgeInsets.all(AppSizes.space), children: [
      if (widget.error != null) Padding(padding: EdgeInsets.only(bottom: AppSizes.space), child: TerminalText(widget.error.toString(), color: Theme.of(context).colorScheme.error, alpha: .9)),
      for (final h in harnesses) HarnessAuthCard(harness: h, status: widget.statuses[h.id], providerKeys: widget.providerKeys,
        codeController: _controller(h.id), isBusy: widget.isHarnessBusy(h.id),
        onStartAccount: () => widget.onStartAccount(h), onStartApiKey: () => widget.onStartApiKey(h),
        onStartNone: () => widget.onStartNone(h), onPoll: () => widget.onPoll(h),
        onSubmit: (code) => widget.onSubmit(h, code), onCancel: () => widget.onCancel(h),
        onDisconnect: () => widget.onDisconnect(h), onRefresh: () => widget.onRefresh(h)),
    ]);
  }
}

class HarnessAuthCard extends StatelessWidget {
  const HarnessAuthCard({super.key, required this.harness, required this.status, required this.providerKeys,
    required this.codeController, required this.isBusy, required this.onStartAccount, required this.onStartApiKey,
    required this.onStartNone, required this.onPoll, required this.onSubmit, required this.onCancel,
    required this.onDisconnect, required this.onRefresh});
  final Harnesse harness; final HarnessAuthStatus? status; final List<ProviderKey> providerKeys;
  final TextEditingController codeController; final bool isBusy; final VoidCallback onStartAccount;
  final VoidCallback onStartApiKey; final VoidCallback onStartNone; final VoidCallback onPoll;
  final Future<void> Function(String) onSubmit; final VoidCallback onCancel; final VoidCallback onDisconnect; final VoidCallback onRefresh;

  @override Widget build(BuildContext context) {
    final s = status ?? HarnessAuthStatus(harness: harness.id, scopeKind: 'user', scopeId: '', bindingId: '', credentialMode: 'none', status: 'disconnected');
    final keys = providerKeys.where((k) => k.provider.toLowerCase() == harness.cliId.toLowerCase()).toList();
    return BiosSection(title: '${harness.name} [${harness.cliId}]', child: TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TerminalText('Status: ${s.status.toUpperCase()}', weight: TerminalTextWeight.heavy),
      if (s.lastError != null && s.lastError!.isNotEmpty) ...[VSpace.x1, TerminalText(s.lastError!, color: Theme.of(context).colorScheme.error)],
      if (s.credentialMode.isNotEmpty) ...[VSpace.x1, TerminalText('Mode: ${s.credentialMode.toUpperCase()}')],
      if (s.bindingId.isNotEmpty) ...[VSpace.x1, TerminalText('Binding: ${s.bindingId}')], VSpace.x2,
      if (s.challenge != null) HarnessChallengePanel(challenge: s.challenge!),
      if (s.challenge != null) ...[VSpace.x1, TerminalTextField(controller: codeController, label: 'One-time code', hint: 'paste code', onSubmitted: _submit, enabled: !isBusy), VSpace.x1,
        Align(alignment: Alignment.centerRight, child: TerminalButton(label: 'Submit', onTap: () => _submit(codeController.text), isLoading: isBusy))],
      VSpace.x2, _actions(context, s, keys.isNotEmpty), VSpace.x2,
      Align(alignment: Alignment.centerLeft, child: TerminalButton(label: 'Refresh', isPrimary: false, isLoading: isBusy, onTap: isBusy ? () {} : onRefresh)),
      if (s.attempt?.id != null) Padding(padding: EdgeInsets.only(top: AppSizes.space), child: TerminalText('Attempt: ${s.attempt!.id}', alpha: .5)),
    ])));
  }
  Widget _actions(BuildContext context, HarnessAuthStatus s, bool hasKeys) {
    if (s.isDisconnected) {
      return Wrap(spacing: AppSizes.space, runSpacing: AppSizes.space, children: [
      TerminalButton(label: 'Account login', onTap: isBusy ? () {} : onStartAccount, isLoading: isBusy),
      TerminalButton(label: 'API key', onTap: hasKeys ? (isBusy ? () {} : onStartApiKey) : () => _noKey(context), isLoading: isBusy),
      TerminalButton(label: 'None', onTap: isBusy ? () {} : onStartNone, isLoading: isBusy, isPrimary: false),
      TerminalButton(label: 'Poll', onTap: isBusy ? () {} : onPoll, isLoading: isBusy, isPrimary: false),]);
    }
    if (s.isConnected) {
      return TerminalButton(label: 'Disconnect', onTap: isBusy ? () {} : onDisconnect, isLoading: isBusy);
    }
    return Wrap(spacing: AppSizes.space, runSpacing: AppSizes.space, children: [TerminalButton(label: 'Poll', onTap: isBusy ? () {} : onPoll, isLoading: isBusy, isPrimary: false), TerminalButton(label: 'Cancel', onTap: isBusy ? () {} : onCancel, isLoading: isBusy)]);
  }
  void _noKey(BuildContext context) => showDialog<void>(context: context, builder: (d) => TerminalDialog(title: 'No API key', content: const Text('No matching provider key exists for this harness. Open the LLM management screen to add a provider key first.'), actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Close'))]));
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
  @override Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: AppSizes.space), padding: EdgeInsets.all(AppSizes.space), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TerminalText('Challenge', weight: TerminalTextWeight.heavy), VSpace.x1, TerminalText(challenge.text),
    if (challenge.target != null && challenge.target!.isNotEmpty) ...[VSpace.x1, GestureDetector(onLongPress: () { Clipboard.setData(ClipboardData(text: challenge.target!)); VimToast.show(context, context.l10n.harnessAuthChallengeTargetCopied); }, child: TerminalText(challenge.target!, color: Theme.of(context).colorScheme.primary, alpha: .9))],
    if (challenge.details != null && challenge.details!.isNotEmpty) ...[VSpace.x1, TerminalText('Details: ${challenge.details}', alpha: .7)],
  ]));
}
