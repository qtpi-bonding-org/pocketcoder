import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketbase/pocketbase.dart';

class HarnessAuthorizationScreen extends StatelessWidget {
  const HarnessAuthorizationScreen({
    super.key,
    required this.harnessId,
    required this.provider,
  });

  final String harnessId;
  final String provider;

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
      child: _HarnessAuthorizationView(
        harnessId: harnessId,
        provider: provider,
      ),
    );
  }
}

class _HarnessAuthorizationView extends StatefulWidget {
  const _HarnessAuthorizationView({
    required this.harnessId,
    required this.provider,
  });

  final String harnessId;
  final String provider;

  @override
  State<_HarnessAuthorizationView> createState() =>
      _HarnessAuthorizationViewState();
}

class _HarnessAuthorizationViewState extends State<_HarnessAuthorizationView> {
  final _codeController = TextEditingController();
  Timer? _pollTimer;
  bool _openedChat = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HarnessAuthCubit, HarnessAuthState>(
      listener: (context, state) {
        final status = state.statuses[widget.harnessId];
        if (status?.isConnected == true) {
          OnboardingLogger.event('harness authorization connected', {
            'harness': widget.harnessId,
            'provider': widget.provider,
          });
          _pollTimer?.cancel();
          _openFirstChat();
        } else if (status?.isConnecting == true) {
          OnboardingLogger.event('harness polling scheduled', {
            'harness': widget.harnessId,
            'provider': widget.provider,
          });
          _pollTimer ??= Timer(const Duration(seconds: 1), () {
            void pollNow() {
              final cubit = context.read<HarnessAuthCubit>();
              if (cubit.state.isBusy) return;
              OnboardingLogger.event('harness polling tick', {
                'harness': widget.harnessId,
                'provider': widget.provider,
              });
              cubit.poll(widget.harnessId);
            }

            _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
              if (mounted) pollNow();
            });
            if (mounted) pollNow();
          });
        }
      },
      child: BlocBuilder<HarnessAuthCubit, HarnessAuthState>(
        builder: (context, state) {
          final status = state.statuses[widget.harnessId];
          return PocketCoderShell(
            title: context.l10n.onboardingHarnessLoginTitle(
              widget.provider.toUpperCase(),
            ),
            activePillar: NavPillar.configure,
            showBack: true,
            body: _buildBody(context, state, status),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HarnessAuthState state,
    HarnessAuthStatus? status,
  ) {
    if (state.isLoading && state.harnesses.isEmpty) {
      return const Center(child: TerminalLoadingIndicator());
    }

    final harness = state.harnesses.where((h) => h.id == widget.harnessId);
    if (harness.isEmpty) {
      return Center(
          child: TerminalText(context.l10n.onboardingHarnessNotFound));
    }

    final current = status ??
        const HarnessAuthStatus(
          harness: '',
          scopeKind: 'user',
          scopeId: '',
          bindingId: '',
          credentialMode: 'none',
          status: 'disconnected',
        );
    final busy = state.isHarnessBusy(widget.harnessId);
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
                    color: current.isConnected
                        ? Colors.green
                        : context.colorScheme.primary,
                    fontFamily: AppFonts.headerFamily,
                    fontSize: AppSizes.fontBig,
                    fontWeight: AppFonts.heavy,
                  ),
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
                    alpha: 0.7,
                  ),
                  VSpace.x2,
                ],
                if (challenge != null) ...[
                  _Challenge(challenge: challenge),
                  VSpace.x2,
                ],
                if (challenge != null && widget.provider == 'claude-code') ...[
                  TerminalTextField(
                    controller: _codeController,
                    label: context.l10n.onboardingAuthorizationCode,
                    hint: context.l10n.onboardingAuthorizationCodeHint,
                    enabled: !busy,
                  ),
                  VSpace.x2,
                  TerminalButton(
                    label: context.l10n.onboardingSubmitCode,
                    isLoading: busy,
                    onTap: () => _submit(context),
                  ),
                ] else if (current.isDisconnected) ...[
                  TerminalButton(
                    label: context.l10n.onboardingAccountLogin,
                    isLoading: busy,
                    onTap: () => _startAccountLogin(context),
                  ),
                ],
                if (current.isConnecting &&
                    (widget.provider == 'codex' || challenge == null)) ...[
                  VSpace.x2,
                  TerminalButton(
                    label: context.l10n.onboardingCheckStatus,
                    isPrimary: false,
                    isLoading: busy,
                    onTap: () =>
                        context.read<HarnessAuthCubit>().poll(widget.harnessId),
                  ),
                ],
                if (current.status == 'error') ...[
                  VSpace.x2,
                  TerminalButton(
                    label: context.l10n.onboardingAccountLogin,
                    isLoading: busy,
                    onTap: () => _startAccountLogin(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      OnboardingLogger.event('harness authorization code validation failed', {
        'harness': widget.harnessId,
      });
      return;
    }
    await context.read<HarnessAuthCubit>().submitCode(
          harnessId: widget.harnessId,
          code: code,
        );
    _codeController.clear();
  }

  Future<void> _startAccountLogin(BuildContext context) async {
    OnboardingLogger.event('harness account login tapped', {
      'harness': widget.harnessId,
      'provider': widget.provider,
    });
    await context.read<HarnessAuthCubit>().startWithAccount(
          harnessId: widget.harnessId,
          provider: widget.provider,
        );
  }

  Future<void> _openFirstChat() async {
    if (_openedChat) return;
    _openedChat = true;
    OnboardingLogger.event('harness connected; creating first chat', {
      'harness': widget.harnessId,
    });
    try {
      final chats = getIt<ChatListCubit>();
      await chats.createAndOpen(harness: widget.harnessId);
      final chatId = chats.state.lastCreatedChatId;
      if (!mounted || chatId == null || chatId.isEmpty) return;
      OnboardingLogger.event('first chat created; entering chat', {
        'harness': widget.harnessId,
      });
      context.go('${AppRoutes.chat}/$chatId');
    } catch (error) {
      _openedChat = false;
      OnboardingLogger.event('first chat creation failed', {
        'harness': widget.harnessId,
        'error': error.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  context.l10n.onboardingOpenChatFailed(error.toString()))),
        );
      }
    }
  }
}

class _Challenge extends StatelessWidget {
  const _Challenge({required this.challenge});

  final HarnessAuthChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final target = challenge.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText(challenge.text),
        if (target != null && target.isNotEmpty) ...[
          VSpace.x2,
          TerminalButton(
            label: context.l10n.onboardingOpenAuthorization,
            onTap: () {
              OnboardingLogger.event('authorization challenge opened', {
                'type': challenge.type,
              });
              launchUrl(Uri.tryParse(target) ?? Uri(),
                  mode: LaunchMode.externalApplication);
            },
          ),
          VSpace.x1,
          SelectableText(target),
        ],
        if (challenge.details != null && challenge.details!.isNotEmpty) ...[
          VSpace.x1,
          TerminalText(challenge.details!, alpha: 0.7),
        ],
      ],
    );
  }
}
