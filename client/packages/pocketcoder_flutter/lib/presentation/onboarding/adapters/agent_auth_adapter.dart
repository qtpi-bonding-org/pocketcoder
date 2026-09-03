import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
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
    final connected = adapter.keep<ValueNotifier<Set<String>>>(
      'connectedHarnessIds',
      () => ValueNotifier(<String>{}),
      dispose: (notifier) => notifier.dispose(),
    );
    return ValueListenableBuilder<UiFlowStatus>(
      valueListenable: status,
      builder: (context, status, _) => ValueListenableBuilder<List<Harnesse>>(
        valueListenable: harnesses,
        builder: (context, harnesses, _) => ValueListenableBuilder<Set<String>>(
          valueListenable: connected,
          builder: (context, connectedIds, _) {
            // connectedIds is monotonic for this screen's lifetime, but
            // harnesses is live and can drop an id it once contained --
            // NEXT must disappear rather than throw if that happens.
            final connectedHarness =
                harnesses.where((h) => connectedIds.contains(h.id)).firstOrNull;
            return AgentAuthView(
              status: status,
              harnesses: harnesses,
              error: context.read<ProviderCubit>().state.error,
              onSelected: (harness) => _select(context, harness, connected),
              harnessProvidersLoaded: auth.state.harnessProvidersLoaded,
              selectedHarnesses: selectedHarnesses,
              connectedHarnessIds: connectedIds,
              onSkip: () => context.go(AppRoutes.chats),
              onContinue: connectedHarness == null
                  ? null
                  : () => _openChat(context, connectedHarness),
            );
          },
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

  Future<void> _select(
    BuildContext context,
    Harnesse harness,
    ValueNotifier<Set<String>> connected,
  ) async {
    final auth = context.read<HarnessAuthCubit>();
    if (!auth.state.harnessProvidersLoaded) {
      VimToast.show(context, context.l10n.onboardingHarnessProvidersLoading);
      return;
    }
    final provider = _oauthProviderFor(auth.state, harness.id);
    if (provider == null) {
      // Multi-provider / non-oauth harness (e.g. Goose, OpenCode): no single
      // oauth-capable edge to log in with. These authenticate via a plain
      // provider_api_keys credential instead (mode: none) -- see
      // _selectWithApiKey.
      await _selectWithApiKey(context, harness, connected);
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
    await _showAuthDialog(context, auth, harness, provider, connected);
  }

  /// mode: none is synchronous (harness_auth.go's StartHarnessAuth just
  /// records the credential, no connecting/polling phase), so no dialog.
  Future<void> _selectWithApiKey(
    BuildContext context,
    Harnesse harness,
    ValueNotifier<Set<String>> connected,
  ) async {
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
      // saveProviderAPIKey goes through tryOperation, which records a
      // failure in cubit state instead of throwing -- awaiting it alone
      // never signals failure to this caller. Without this check, a save
      // that failed on the server (e.g. a rejected create) was silently
      // treated as success: onboarding proceeded to select a provider with
      // no credential actually persisted, so the harness could never be
      // provisioned and every chat prompt failed with a permanent
      // "Harness is starting" retry loop.
      if (providerCubit.state.status == UiFlowStatus.failure) return;
      providerId = saved.provider;
    }

    OnboardingLogger.event(
        'harness selected', {'harness': harness.id, 'provider': providerId});
    if (!context.mounted) return;
    await auth.startWithNone(harness.id,
        provider: providerId, visibility: harnessAccountVisibilityPersonal);
    // startWithNone goes through _withBusy, which records a failure in
    // cubit state instead of throwing -- same swallowed-failure hazard as
    // saveProviderAPIKey above.
    if (auth.state.status == UiFlowStatus.failure) return;
    connected.value = {...connected.value, harness.id};
  }

  Future<void> _openChat(BuildContext context, Harnesse harness) async {
    final chats = context.read<ChatListCubit>();
    try {
      await chats.createAndOpen(harness: harness.id);
      final chatId = chats.state.lastCreatedChatId;
      if (context.mounted && chatId != null && chatId.isNotEmpty) {
        context.go('/chat/$chatId');
        unawaited(_requestPushPermissionSilently());
      }
    } catch (error) {
      OnboardingLogger.event(
          'first chat creation failed', {'error': error.toString()});
    }
  }

  Future<void> _requestPushPermissionSilently() async {
    try {
      await getIt<PushService>().requestPermissions();
    } catch (error) {
      OnboardingLogger.event(
          'push_permission_request_failed', {'error': '$error'});
    }
  }

  Future<void> _showAuthDialog(
    BuildContext context,
    HarnessAuthCubit auth,
    Harnesse harness,
    String provider,
    ValueNotifier<Set<String>> connected,
  ) async {
    Timer? timer;
    int? timerInterval;
    var dialogClosing = false;
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
                if (!auth.state.isHarnessBusy(harness.id)) {
                  unawaited(auth.poll(harness.id, provider));
                }
              });
            }
          } else {
            // A terminal response (failure, cancellation, or disconnect)
            // must stop polling before the dialog is dismissed.  In
            // particular, a failure can leave this builder mounted so that
            // the user can retry.
            timer?.cancel();
            timer = null;
            timerInterval = null;
          }
          if (status?.isConnected == true && !dialogClosing) {
            timer?.cancel();
            timer = null;
            timerInterval = null;
            dialogClosing = true;
            // Deferred: connected has its own ValueListenableBuilder
            // listener elsewhere, which cannot rebuild while this
            // BlocBuilder is still mid-build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              connected.value = {...connected.value, harness.id};
              Navigator.of(dialogContext).pop();
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
                TerminalLoadingIndicator(
                  label: harness.name,
                  status: status?.isConnecting == true
                      ? TerminalStatus.running
                      : errorMessage != null
                          ? TerminalStatus.failure
                          : TerminalStatus.running,
                ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.serverControlCopied)),
                    );
                  },
                  onSubmitCode: (code) => auth.submitCode(
                      harnessId: harness.id, code: code, provider: provider),
                  onCancel: () async {
                    timer?.cancel();
                    timer = null;
                    timerInterval = null;
                    await auth.cancel(harness.id, provider);
                    if (dialogContext.mounted && !dialogClosing) {
                      dialogClosing = true;
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  onRetry: () => auth.startWithAccount(
                    harnessId: harness.id,
                    provider: provider,
                    visibility: harnessAccountVisibilityPersonal,
                  ),
                ),
              ],
            ),
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
