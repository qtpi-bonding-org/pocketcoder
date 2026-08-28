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
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/credential_connection_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/agent_auth_view.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class AgentAuthAdapter extends CubitAdapter<ProviderCubit, ProviderState> {
  const AgentAuthAdapter({super.key, required this.launcher});

  final InAppBrowserLauncher launcher;

  static List<Harnesse> selectHarnesses(ProviderState state) => state.harnesses;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ProviderCubit, ProviderState> adapter,
  ) {
    final harnesses = adapter.cubitField(selectHarnesses);
    final auth = context.read<HarnessAuthCubit>();
    final status = adapter.cubitStatus();
    final selectedHarnesses = ReleaseStatusScope.maybeOf(context)
            ?.state
            .snapshot
            ?.selectedHarnesses ??
        const [];
    return ValueListenableBuilder<UiFlowStatus>(
      valueListenable: status,
      builder: (context, status, _) => ValueListenableBuilder<List<Harnesse>>(
        valueListenable: harnesses,
        builder: (context, harnesses, _) => AgentAuthView(
          status: status,
          harnesses: harnesses,
          error: context.read<ProviderCubit>().state.error,
          onSelected: (harness) => _select(context, harness),
          harnessProvidersLoaded: auth.state.harnessProvidersLoaded,
          selectedHarnesses: selectedHarnesses,
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
    if (!auth.state.harnessProvidersLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading harness providers…')));
      return;
    }
    final provider = _oauthProviderFor(auth.state, harness.id);
    if (provider == null) {
      // Multi-provider / non-oauth harness (e.g. Goose, OpenCode): no single
      // oauth-capable edge to log in with. These authenticate via a plain
      // provider_api_keys credential instead (mode: none) -- see
      // _selectWithApiKey.
      await _selectWithApiKey(context, harness);
      return;
    }
    OnboardingLogger.event(
        'harness selected', {'harness': harness.id, 'provider': provider});

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

  /// mode: none is synchronous on the server (it just records which
  /// provider's credential to use -- see harness_auth.go's StartHarnessAuth,
  /// there is no connecting/polling phase at all), so this never opens the
  /// OAuth dialog: it resolves a provider (an existing key, or one just
  /// entered), starts the credential selection, and goes straight to chat.
  Future<void> _selectWithApiKey(BuildContext context, Harnesse harness) async {
    final auth = context.read<HarnessAuthCubit>();
    final providerCubit = context.read<ProviderCubit>();
    final providerIds = auth.state.harnessProviders
        .where((edge) => edge.harness == harness.id)
        .map((edge) => edge.provider)
        .toSet();
    if (providerIds.isEmpty) return; // this harness has no usable provider yet

    var providerId = providerCubit.state.providerAPIKeys
        .where((key) => providerIds.contains(key.provider))
        .firstOrNull
        ?.provider;

    if (providerId == null) {
      final catalog = providerCubit.state.providerCatalog
          .where((p) => providerIds.contains(p.id))
          .toList();
      if (catalog.isEmpty) return; // provider catalog hasn't loaded yet
      final saved = await showDialog<ProviderApiKey>(
        context: context,
        builder: (dialogContext) => ProviderKeyEditorDialog(
          providerCatalog: catalog,
          onSave: (key) => Navigator.of(dialogContext).pop(key),
        ),
      );
      if (saved == null) return; // user cancelled
      await providerCubit.saveProviderAPIKey(saved);
      providerId = saved.provider;
    }

    OnboardingLogger.event(
        'harness selected', {'harness': harness.id, 'provider': providerId});
    if (!context.mounted) return;
    await auth.startWithNone(harness.id,
        provider: providerId, visibility: harnessAccountVisibilityPersonal);
    if (!context.mounted) return;
    await _openChat(context, harness);
  }

  Future<void> _openChat(BuildContext context, Harnesse harness) async {
    final chats = context.read<ChatListCubit>();
    try {
      await chats.createAndOpen(harness: harness.id);
      final chatId = chats.state.lastCreatedChatId;
      if (context.mounted && chatId != null && chatId.isNotEmpty) {
        context.go('/chat/$chatId');
      }
    } catch (error) {
      OnboardingLogger.event(
          'first chat creation failed', {'error': error.toString()});
    }
  }

  Future<void> _showAuthDialog(
    BuildContext context,
    HarnessAuthCubit auth,
    Harnesse harness,
    String provider,
  ) async {
    Timer? timer;
    int? timerInterval;
    var openedChat = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          BlocBuilder<HarnessAuthCubit, HarnessAuthState>(
        bloc: auth,
        builder: (context, state) {
          final status = state.statusFor(harness.id, provider);
          if (status?.isConnecting == true) {
            final interval = status?.challenge?.pollIntervalSeconds ?? 4;
            if (timer == null || timerInterval != interval) {
              timer?.cancel();
              timerInterval = interval;
              timer = Timer.periodic(Duration(seconds: interval), (_) {
                if (!auth.state.isHarnessBusy(harness.id))
                  unawaited(auth.poll(harness.id, provider));
              });
            }
          }
          if (status?.isConnected == true && !openedChat) {
            openedChat = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              Navigator.of(dialogContext).pop();
              // The caller's shell remains underneath the modal; chat is
              // entered exactly as the retired login screen did.
              await _openChat(context, harness);
            });
          }
          final challenge = status?.challenge;
          final uri = challenge?.verificationUri;
          final destination = challenge?.codeDestination;
          final step = uri != null &&
                  (destination == HarnessAuthCodeDestination.browser ||
                      destination == HarnessAuthCodeDestination.app)
              ? BrowserVerificationConnectionStep(
                  verificationUri: uri,
                  codeDestination:
                      destination ?? HarnessAuthCodeDestination.unknown,
                  userCode: challenge?.userCode,
                  expiresAt: challenge?.expiresAt,
                )
              : const ApiKeyConnectionStep();
          final errorMessage = status?.lastError ??
              (state.status == UiFlowStatus.failure
                  ? context.l10n.errorGeneric
                  : null);
          return TerminalDialog(
            title: context.l10n.externalAuthTitle,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TerminalLoadingIndicator(label: harness.name),
                TerminalText(
                  context.l10n.externalAuthConnecting(harness.name),
                  alpha: status?.isConnecting == true ? 1 : .6,
                ),
                if (errorMessage case final message?) TerminalText(message),
                if (step is ApiKeyConnectionStep && challenge != null)
                  if (challenge.legacyText case final legacyText?
                      when legacyText.isNotEmpty)
                    TerminalText(legacyText),
                CredentialConnectionView(
                  step: step,
                  onOpenAuthorizationPage: () {
                    if (uri != null) unawaited(_openChallenge(context, uri));
                  },
                  onCopyCode: (code) {
                    // The view handles the clipboard operation; this callback
                    // remains available for adapter-side analytics/future use.
                  },
                  onSubmitCode: (code) => auth.submitCode(
                      harnessId: harness.id, code: code, provider: provider),
                  onCancel: () async {
                    await auth.cancel(harness.id, provider);
                    if (dialogContext.mounted)
                      Navigator.of(dialogContext).pop();
                  },
                  onRetry: () => auth.startWithAccount(
                    harnessId: harness.id,
                    provider: provider,
                    visibility: harnessAccountVisibilityPersonal,
                  ),
                ),
              ],
            ),
            // CredentialConnectionView owns the cancel/retry controls and
            // receives the adapter's side-effect callbacks above.
            actions: const [],
          );
        },
      ),
    );
    timer?.cancel();
  }

  Future<void> _openChallenge(BuildContext context, Uri uri) async {
    final opened = await launcher.open(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorCouldNotOpenBrowser)));
    }
  }
}
