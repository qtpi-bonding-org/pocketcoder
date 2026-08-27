import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/external_auth_dialog.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/agent_auth_view.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentAuthAdapter extends CubitAdapter<ProviderCubit, ProviderState> {
  const AgentAuthAdapter({super.key});

  static List<Harnesse> selectHarnesses(ProviderState state) => state.harnesses;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ProviderCubit, ProviderState> adapter,
  ) {
    final harnesses = adapter.cubitField(selectHarnesses);
    final status = adapter.cubitStatus();
    return ValueListenableBuilder<UiFlowStatus>(
      valueListenable: status,
      builder: (context, status, _) => ValueListenableBuilder<List<Harnesse>>(
        valueListenable: harnesses,
        builder: (context, harnesses, _) => AgentAuthView(
          status: status,
          harnesses: harnesses,
          error: context.read<ProviderCubit>().state.error,
          onSelected: (harness) => _select(context, harness),
        ),
      ),
    );
  }

  /// The one harness_providers edge this harness supports account login for
  /// -- mirrors HarnessAuthCubit's own private _oauthProviderFor, since this
  /// adapter needs the same (harness, provider) resolution to call
  /// startWithAccount/cancel/submitCode with the PocketBase providers
  /// record id the API now requires (Task 9), not the harness's cli_id.
  static String? _oauthProviderFor(HarnessAuthState state, String harnessId) {
    for (final edge in state.harnessProviders) {
      if (edge.harness == harnessId && edge.supportsOauth == true) {
        return edge.provider;
      }
    }
    return null;
  }

  Future<void> _select(BuildContext context, Harnesse harness) async {
    final auth = context.read<HarnessAuthCubit>();
    final provider = _oauthProviderFor(auth.state, harness.id);
    if (provider == null) return; // no oauth-capable provider for this harness
    OnboardingLogger.event('harness selected', {'harness': harness.id, 'provider': provider});

    // Decision 4: selecting an agent is the authorization action. The former
    // visibility confirmation is intentionally not part of this golden path.
    unawaited(auth.startWithAccount(
      harnessId: harness.id,
      provider: provider,
      visibility: harnessAccountVisibilityPersonal,
    ));
    if (!context.mounted) return;
    await _showAuthDialog(context, auth, harness, provider);
  }

  Future<void> _showAuthDialog(
    BuildContext context,
    HarnessAuthCubit auth,
    Harnesse harness,
    String provider,
  ) async {
    Timer? timer;
    var openedChat = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocBuilder<HarnessAuthCubit, HarnessAuthState>(
        bloc: auth,
        builder: (context, state) {
          final status = state.statuses[harness.id];
          if (status?.isConnecting == true) {
            timer ??= Timer.periodic(const Duration(seconds: 4), (_) {
              if (!auth.state.isHarnessBusy(harness.id)) unawaited(auth.poll(harness.id));
            });
          }
          if (status?.isConnected == true && !openedChat) {
            openedChat = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              Navigator.of(dialogContext).pop();
              final chats = context.read<ChatListCubit>();
              try {
                await chats.createAndOpen(harness: harness.id);
                final chatId = chats.state.lastCreatedChatId;
                if (context.mounted && chatId != null && chatId.isNotEmpty) {
                  // The caller's shell remains underneath the modal; chat is
                  // entered exactly as the retired login screen did.
                  context.go('/chat/$chatId');
                }
              } catch (error) {
                OnboardingLogger.event('first chat creation failed', {'error': error.toString()});
              }
            });
          }
          return ExternalAuthDialog(
            label: harness.name,
            isLoading: status?.isConnecting ?? state.isBusy,
            errorMessage: status?.lastError ??
                (state.status == UiFlowStatus.failure ? context.l10n.errorGeneric : null),
            onCancel: () async {
              await auth.cancel(harness.id);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            onRetry: () => auth.startWithAccount(
              harnessId: harness.id,
              provider: provider,
              visibility: harnessAccountVisibilityPersonal,
            ),
            challengeText: status?.challenge?.text,
            challengeTarget: status?.challenge?.target,
            onOpenChallenge: status?.challenge == null
                ? null
                : () => _openChallenge(context, status!.challenge!),
            showCodeInput: state.harnessProviders.any((edge) =>
                    edge.harness == harness.id &&
                    edge.provider == provider &&
                    edge.oauthAuthenticator == 'claude') &&
                status?.challenge != null,
            onSubmitCode: (code) => auth.submitCode(harnessId: harness.id, code: code),
            isBusy: state.isHarnessBusy(harness.id),
          );
        },
      ),
    );
    timer?.cancel();
  }

  Future<void> _openChallenge(BuildContext context, HarnessAuthChallenge challenge) async {
    final target = challenge.target;
    if (target == null || target.isEmpty) return;
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorCouldNotOpenBrowser)));
    }
  }
}
