import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_actions_block.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_status_block.dart';

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
    required this.providerCatalog,
    required this.providerAPIKeys,
    required this.onStartAccount,
    required this.onUseApiKey,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
    required this.onOpenAuthorizationPage});

  final bool onboarding;
  final List<Harnesse> harnesses;
  final List<HarnessProvider> harnessProviders;
  final Map<HarnessProviderKey, HarnessAuthStatus> statuses;
  final Object? error;
  final bool isLoading;
  final bool Function(String) isHarnessBusy;
  final List<domain.Provider> providerCatalog;
  final List<ProviderApiKey> providerAPIKeys;
  final Future<void> Function(Harnesse, String) onStartAccount;
  final Future<void> Function(Harnesse) onUseApiKey;
  final Future<void> Function(Harnesse, String) onSubmit;
  final void Function(Harnesse) onCancel;
  final void Function(Harnesse) onDisconnect;
  final void Function(Harnesse) onRefresh;
  final void Function(Harnesse, Uri) onOpenAuthorizationPage;

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
          providerCatalog: providerCatalog,
          providerAPIKeys: providerAPIKeys,
          onStartAccount: onStartAccount,
          onUseApiKey: onUseApiKey,
          onSubmit: onSubmit,
          onCancel: onCancel,
          onDisconnect: onDisconnect,
          onRefresh: onRefresh,
          onOpenAuthorizationPage: onOpenAuthorizationPage));
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
    required this.providerCatalog,
    required this.providerAPIKeys,
    required this.onStartAccount,
    required this.onUseApiKey,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
    required this.onOpenAuthorizationPage});
  final bool onboarding;
  final List<Harnesse> harnesses;
  final List<HarnessProvider> harnessProviders;
  final Map<HarnessProviderKey, HarnessAuthStatus> statuses;
  final Object? error;
  final bool isLoading;
  final bool Function(String) isHarnessBusy;
  final List<domain.Provider> providerCatalog;
  final List<ProviderApiKey> providerAPIKeys;
  final Future<void> Function(Harnesse, String) onStartAccount;
  final Future<void> Function(Harnesse) onUseApiKey;
  final Future<void> Function(Harnesse, String) onSubmit;
  final void Function(Harnesse) onCancel;
  final void Function(Harnesse) onDisconnect;
  final void Function(Harnesse) onRefresh;
  final void Function(Harnesse, Uri) onOpenAuthorizationPage;

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

  HarnessAuthStatus? _statusFor(Harnesse harness) {
    final provider = widget.harnessProviders
        .where(
            (edge) => edge.harness == harness.id && edge.supportsOauth == true)
        .firstOrNull
        ?.provider;
    return provider == null
        ? null
        : widget.statuses[HarnessProviderKey(harness.id, provider)];
  }

  domain.Provider? _configuredApiKeyProviderFor(Harnesse harness) {
    final providerIds = widget.harnessProviders
        .where((edge) => edge.harness == harness.id)
        .map((edge) => edge.provider)
        .toSet();
    final matchingProviderId = widget.providerAPIKeys
        .where((key) => providerIds.contains(key.provider))
        .firstOrNull
        ?.provider;
    if (matchingProviderId == null) return null;
    return widget.providerCatalog
        .where((p) => p.id == matchingProviderId)
        .firstOrNull;
  }

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
              role: TextRole.label,
          ));
    }
    return ListView(padding: EdgeInsets.all(AppSizes.space), children: [
      if (widget.error != null)
        Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: TerminalText(safeErrorMessage(widget.error),
                role: TextRole.warn)),
      for (final h in harnesses)
        HarnessAuthCard(
            harness: h,
            harnessProviders: widget.harnessProviders,
            status: _statusFor(h),
            configuredApiKeyProvider: _configuredApiKeyProviderFor(h),
            codeController: _controller(h.id),
            isBusy: widget.isHarnessBusy(h.id),
            onStartAccount: (provider) => widget.onStartAccount(h, provider),
            onUseApiKey: () => widget.onUseApiKey(h),
            onSubmit: (code) => widget.onSubmit(h, code),
            onCancel: () => widget.onCancel(h),
            onDisconnect: () => widget.onDisconnect(h),
            onRefresh: () => widget.onRefresh(h),
            onOpenAuthorizationPage: (uri) =>
                widget.onOpenAuthorizationPage(h, uri),
            onCopyCode: (_) {}),
    ]);
  }
}

class HarnessAuthCard extends StatelessWidget {
  const HarnessAuthCard(
      {super.key,
      required this.harness,
      required this.harnessProviders,
      required this.status,
      required this.configuredApiKeyProvider,
      required this.codeController,
      required this.isBusy,
      required this.onStartAccount,
      required this.onUseApiKey,
      required this.onSubmit,
      required this.onCancel,
      required this.onDisconnect,
      required this.onRefresh,
      required this.onOpenAuthorizationPage,
      required this.onCopyCode});
  final Harnesse harness;
  final List<HarnessProvider> harnessProviders;
  final domain.Provider? configuredApiKeyProvider;
  final VoidCallback onUseApiKey;
  final HarnessAuthStatus? status;
  final TextEditingController codeController;
  final bool isBusy;
  final void Function(String) onStartAccount;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;
  final void Function(Uri) onOpenAuthorizationPage;
  final ValueChanged<String> onCopyCode;

  @override
  Widget build(BuildContext context) {
    final edges =
        harnessProviders.where((p) => p.harness == harness.id).toList();
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
    return HarnessAuthStatusBlock(
      harness: harness,
      status: status,
      configuredApiKeyProvider: configuredApiKeyProvider,
      child: HarnessAuthActionsBlock(
        harness: harness,
        status: s,
        edges: edges,
        codeController: codeController,
        isBusy: isBusy,
        onStartAccount: onStartAccount,
        onUseApiKey: onUseApiKey,
        onSubmit: onSubmit,
        onCancel: onCancel,
        onDisconnect: onDisconnect,
        onRefresh: onRefresh,
        onOpenAuthorizationPage: onOpenAuthorizationPage,
        onCopyCode: onCopyCode));
  }
}
