import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class HarnessAuthScreen extends StatelessWidget {
  const HarnessAuthScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HarnessAuthCubit(
        providerRepository: getIt<IProviderRepository>(),
        authRepository: HarnessAuthRepository(
          getIt<PocketBase>(),
          getIt<IAuthRepository>(),
        ),
      )..watchData(),
      child: HarnessAuthView(onboarding: onboarding),
    );
  }
}

class HarnessAuthView extends StatefulWidget {
  const HarnessAuthView({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<HarnessAuthView> createState() => _HarnessAuthViewState();
}

class _HarnessAuthViewState extends State<HarnessAuthView> {
  final Map<String, TextEditingController> _codeControllers = {};
  bool _openedFirstChat = false;

  TextEditingController _codeControllerFor(String harnessId) {
    return _codeControllers.putIfAbsent(
      harnessId,
      TextEditingController.new,
    );
  }

  @override
  void dispose() {
    for (final c in _codeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HarnessAuthCubit, HarnessAuthState>(
      listenWhen: (previous, current) =>
          widget.onboarding &&
          !_hasConnected(previous) &&
          _hasConnected(current),
      listener: (context, state) => _openFirstChat(context, state),
      child: BlocBuilder<HarnessAuthCubit, HarnessAuthState>(
        builder: (context, state) {
          return PocketCoderShell(
            title:
                widget.onboarding ? 'CONNECT A HARNESS' : 'Harness connections',
            activePillar: NavPillar.configure,
            showBack: true,
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  bool _isOnboardingHarness(Harnesse harness) {
    if (!widget.onboarding) return true;
    final cli = harness.cliId.trim().toLowerCase();
    return cli == 'claude-code' || cli == 'codex';
  }

  bool _hasConnected(HarnessAuthState state) => state.harnesses
      .where(_isOnboardingHarness)
      .any((h) => state.statuses[h.id]?.isConnected == true);

  Future<void> _openFirstChat(
    BuildContext context,
    HarnessAuthState state,
  ) async {
    if (_openedFirstChat) return;
    _openedFirstChat = true;
    final connected = state.harnesses
        .where(_isOnboardingHarness)
        .firstWhere((h) => state.statuses[h.id]?.isConnected == true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chats = getIt<ChatListCubit>();
      await chats.createAndOpen(harness: connected.id);
      final chatId = chats.state.lastCreatedChatId;
      if (!mounted || chatId == null || chatId.isEmpty) return;
      router.go('${AppRoutes.chat}/$chatId');
    } catch (error) {
      _openedFirstChat = false;
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open a new chat: $error')),
        );
      }
    }
  }

  Widget _buildBody(BuildContext context, HarnessAuthState state) {
    if (state.isLoading && state.harnesses.isEmpty) {
      return Center(
        child: TerminalLoadingIndicator(label: 'Loading harnesses'),
      );
    }

    final harnesses = state.harnesses.where(_isOnboardingHarness).toList();

    if (harnesses.isEmpty) {
      return Center(
        child: TerminalText(
          widget.onboarding
              ? 'Claude Code and Codex are not available on this server.'
              : 'No harnesses were found.',
          alpha: 0.6,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppSizes.space),
      children: [
        if (state.error != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: TerminalText(
              state.error.toString(),
              color: Theme.of(context).colorScheme.error,
              alpha: 0.9,
            ),
          ),
        for (final harness in harnesses)
          _HarnessCard(
            harness: harness,
            status: state.statuses[harness.id],
            providerKeys: state.providerKeys,
            codeController: _codeControllerFor(harness.id),
            isBusy: state.isHarnessBusy(harness.id),
            onStartAccount: () => _startAccount(context, harness),
            onStartApiKey: () => _startApiKey(context, harness),
            onStartNone: () => _startNone(context, harness),
            onPoll: () => context.read<HarnessAuthCubit>().poll(harness.id),
            onSubmit: (code) => context.read<HarnessAuthCubit>().submitCode(
                  harnessId: harness.id,
                  code: code,
                ),
            onCancel: () => context.read<HarnessAuthCubit>().cancel(harness.id),
            onDisconnect: () =>
                context.read<HarnessAuthCubit>().disconnect(harness.id),
            onRefresh: () =>
                context.read<HarnessAuthCubit>().refreshHarness(harness.id),
          ),
      ],
    );
  }

  void _startAccount(BuildContext context, Harnesse harness) {
    final provider = harness.cliId.trim();
    if (provider.isEmpty) {
      _showError(
          context, 'This harness does not expose a provider identifier.');
      return;
    }
    context.read<HarnessAuthCubit>().startWithAccount(
          harnessId: harness.id,
          provider: provider,
        );
  }

  Future<void> _startApiKey(BuildContext context, Harnesse harness) async {
    final cubit = context.read<HarnessAuthCubit>();
    final matching =
        cubit.providerKeysForHarness(harness.cliId.trim().toLowerCase());
    if (matching.isEmpty) {
      _showError(context, 'No provider key found for ${harness.cliId}.');
      return;
    }
    final selected = await _showProviderKeyChooser(context, matching);
    if (selected == null || !mounted) return;
    cubit.startWithApiKey(
      harnessId: harness.id,
      providerKey: selected,
    );
  }

  void _startNone(BuildContext context, Harnesse harness) {
    context.read<HarnessAuthCubit>().startWithNone(harness.id);
  }

  void _showError(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _showProviderKeyChooser(
    BuildContext context,
    List<ProviderKey> keys,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return TerminalDialog(
          title: 'Choose provider key',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final key in keys)
                ListTile(
                  title: Text(key.id),
                  subtitle: Text(
                    key.provider.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop(key.id);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _HarnessCard extends StatelessWidget {
  const _HarnessCard({
    required this.harness,
    required this.status,
    required this.providerKeys,
    required this.codeController,
    required this.isBusy,
    required this.onStartAccount,
    required this.onStartApiKey,
    required this.onStartNone,
    required this.onPoll,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
  });

  final Harnesse harness;
  final HarnessAuthStatus? status;
  final List<ProviderKey> providerKeys;
  final TextEditingController codeController;
  final bool isBusy;
  final VoidCallback onStartAccount;
  final VoidCallback onStartApiKey;
  final VoidCallback onStartNone;
  final VoidCallback onPoll;
  final Future<void> Function(String code) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final authStatus = status ??
        HarnessAuthStatus(
          harness: harness.id,
          scopeKind: 'user',
          scopeId: '',
          bindingId: '',
          credentialMode: 'none',
          status: 'disconnected',
        );
    final statusText = authStatus.status.toUpperCase();
    final keysForHarness = _providerKeysForHarness();

    final challenge = authStatus.challenge;

    return BiosSection(
      title: '${harness.name} [${harness.cliId}]',
      child: TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalText('Status: $statusText',
                weight: TerminalTextWeight.heavy),
            if (authStatus.lastError != null &&
                authStatus.lastError!.isNotEmpty) ...[
              VSpace.x1,
              TerminalText(
                authStatus.lastError!,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            if (authStatus.credentialMode.isNotEmpty) ...[
              VSpace.x1,
              TerminalText('Mode: ${authStatus.credentialMode.toUpperCase()}'),
            ],
            if (authStatus.bindingId.isNotEmpty) ...[
              VSpace.x1,
              TerminalText('Binding: ${authStatus.bindingId}'),
            ],
            VSpace.x2,
            if (challenge != null) _ChallengePanel(challenge: challenge),
            if (challenge != null) ...[
              VSpace.x1,
              TerminalTextField(
                controller: codeController,
                label: 'One-time code',
                hint: 'paste code',
                onSubmitted: (code) => _submit(context, code),
                enabled: !isBusy,
              ),
              VSpace.x1,
              Align(
                alignment: Alignment.centerRight,
                child: TerminalButton(
                  label: 'Submit',
                  onTap: () => _submit(context, codeController.text),
                  isLoading: isBusy,
                ),
              ),
            ],
            VSpace.x2,
            _actionButtons(context, authStatus, keysForHarness.isNotEmpty),
            VSpace.x2,
            Align(
              alignment: Alignment.centerLeft,
              child: TerminalButton(
                label: 'Refresh',
                isPrimary: false,
                isLoading: isBusy,
                onTap: isBusy ? () {} : onRefresh,
              ),
            ),
            if (authStatus.attempt?.id != null)
              Padding(
                padding: EdgeInsets.only(top: AppSizes.space),
                child: TerminalText(
                  'Attempt: ${authStatus.attempt!.id}',
                  alpha: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<ProviderKey> _providerKeysForHarness() {
    if (harness.cliId.isEmpty) return const [];
    final target = harness.cliId.toLowerCase();
    return providerKeys
        .where((key) => key.provider.toLowerCase() == target)
        .toList();
  }

  Widget _actionButtons(
    BuildContext context,
    HarnessAuthStatus status,
    bool hasProviderKeys,
  ) {
    if (status.isDisconnected) {
      return Wrap(
        spacing: AppSizes.space,
        runSpacing: AppSizes.space,
        children: [
          TerminalButton(
            label: 'Account login',
            onTap: isBusy ? () {} : onStartAccount,
            isLoading: isBusy,
          ),
          TerminalButton(
            label: hasProviderKeys ? 'API key' : 'API key',
            onTap: hasProviderKeys
                ? (isBusy ? () {} : onStartApiKey)
                : () {
                    _showNoProviderKeyNotice(context);
                  },
            isLoading: isBusy,
          ),
          TerminalButton(
            label: 'None',
            onTap: isBusy ? () {} : onStartNone,
            isLoading: isBusy,
            isPrimary: false,
          ),
          TerminalButton(
            label: 'Poll',
            onTap: isBusy ? () {} : onPoll,
            isLoading: isBusy,
            isPrimary: false,
          ),
        ],
      );
    }

    if (status.isConnected) {
      return TerminalButton(
        label: 'Disconnect',
        onTap: isBusy ? () {} : onDisconnect,
        isLoading: isBusy,
      );
    }

    return Wrap(
      spacing: AppSizes.space,
      runSpacing: AppSizes.space,
      children: [
        TerminalButton(
          label: 'Poll',
          onTap: isBusy ? () {} : onPoll,
          isLoading: isBusy,
          isPrimary: false,
        ),
        TerminalButton(
          label: 'Cancel',
          onTap: isBusy ? () {} : onCancel,
          isLoading: isBusy,
        ),
      ],
    );
  }

  void _showNoProviderKeyNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: 'No API key',
        content: const Text(
          'No matching provider key exists for this harness. Open the LLM management screen to add a provider key first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || isBusy) return;
    await onSubmit(trimmed);
    codeController.clear();
  }
}

class _ChallengePanel extends StatelessWidget {
  const _ChallengePanel({required this.challenge});

  final HarnessAuthChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerminalText('Challenge', weight: TerminalTextWeight.heavy),
          VSpace.x1,
          TerminalText(challenge.text),
          if (challenge.target != null && challenge.target!.isNotEmpty) ...[
            VSpace.x1,
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: challenge.target!));
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Challenge target copied')),
                );
              },
              child: TerminalText(
                challenge.target!,
                color: Theme.of(context).colorScheme.primary,
                alpha: 0.9,
              ),
            ),
          ],
          if (challenge.details != null && challenge.details!.isNotEmpty) ...[
            VSpace.x1,
            TerminalText(
              'Details: ${challenge.details}',
              alpha: 0.7,
            ),
          ],
        ],
      ),
    );
  }
}
