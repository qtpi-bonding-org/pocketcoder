import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_decider.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_link_builder.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/self_host_login_view.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import '../../../app_router.dart';

class SelfHostLoginAdapter extends CubitAdapter<AuthCubit, AuthState> {
  SelfHostLoginAdapter({
    super.key,
    this.prefill,
    this.setupWatchdog = const Duration(seconds: 10),
  });

  final OnboardingPrefill? prefill;
  final Duration setupWatchdog;
  final _url = ValueNotifier<String>('');
  final _email = ValueNotifier<String>('');
  final _password = ValueNotifier<String>('');
  final _pocoMessage = ValueNotifier<String>('');
  final _pocoSequence = ValueNotifier<List<(String, int)>>(const []);
  final List<String> _pocoHistory = const [];

  static UiFlowStatus selectStatus(AuthState state) => state.status;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<AuthCubit, AuthState> adapter,
  ) {
    final status = adapter.cubitField(selectStatus);
    final watchdog = adapter.keep<_SetupWatchdog>(
      #setupWatchdog,
      _SetupWatchdog.new,
      dispose: (w) => w.dispose(),
    );
    adapter.listenTo(
        #authStatus, status, () => _handleAuthStatus(context, watchdog));
    _initialize(context);

    return ListenableBuilder(
      listenable: Listenable.merge([status, watchdog.stalled]),
      builder: (context, _) => SelfHostLoginView(
        initialUrl: _url.value,
        initialEmail: _email.value,
        initialPassword: _password.value,
        status: status.value,
        pocoMessage: _pocoMessage.value,
        pocoSequence: _pocoSequence.value,
        pocoHistory: _pocoHistory,
        onDeploy: () => context.pushNamed(RouteNames.onboardingWelcome),
        onLogin: (url, email, password) =>
            _login(context, url, email, password),
        onRetrySetup: watchdog.stalled.value
            ? () => _retrySetup(context, watchdog)
            : null,
        errorInboxLink: const ErrorInboxLinkBuilder(),
      ),
    );
  }

  void _armWatchdog(BuildContext context, _SetupWatchdog watchdog) {
    watchdog.arm(setupWatchdog, () {
      if (!context.mounted) return;
      OnboardingLogger.event('existing server connected; setup stalled');
      _pocoMessage.value = context.l10n.onboardingLoginSetupStalled;
      _pocoSequence.value = PocoExpressions.nervous;
    });
  }

  void _retrySetup(BuildContext context, _SetupWatchdog watchdog) {
    OnboardingLogger.event('existing server connected; retrying setup');
    _pocoMessage.value = context.l10n.onboardingPocoWelcome;
    _pocoSequence.value = PocoExpressions.happy;
    _armWatchdog(context, watchdog);
    if (GetIt.I.isRegistered<BootRoutingDecider>()) {
      unawaited(GetIt.I<BootRoutingDecider>().retryAuth());
    }
  }

  void _initialize(BuildContext context) {
    if (_pocoMessage.value.isNotEmpty) return;
    _url.value = prefill?.url ?? 'http://127.0.0.1:8090';
    _email.value = prefill?.email ?? '';
    _password.value = prefill?.password ?? '';
    _pocoMessage.value = context.l10n.onboardingPocoChallengeMessage;
    _pocoSequence.value = PocoExpressions.scanning;
    final savedUrl = context.read<AuthCubit>().state.savedUrl;
    if (prefill == null && savedUrl != null) _url.value = savedUrl;
  }

  void _handleAuthStatus(BuildContext context, _SetupWatchdog watchdog) {
    final state = context.read<AuthCubit>().state;
    if (state.status == UiFlowStatus.success) {
      _armWatchdog(context, watchdog);
    } else {
      watchdog.reset();
    }
    if (state.status == UiFlowStatus.loading) {
      _pocoSequence.value = PocoExpressions.scanning;
    } else if (state.status == UiFlowStatus.success) {
      OnboardingLogger.event(
          'existing server connected; opening harness choice');
      _pocoMessage.value = context.l10n.onboardingPocoWelcome;
      _pocoSequence.value = PocoExpressions.happy;
    } else if (state.status == UiFlowStatus.failure) {
      // Mapped/localized, never state.error's raw text.
      final mapped = safeErrorMessage(state.error);
      _pocoMessage.value =
          mapped.isNotEmpty ? mapped : context.l10n.onboardingAccessDenied;
      _pocoSequence.value = PocoExpressions.nervous;
    }
  }

  Future<void> _login(
    BuildContext context,
    String url,
    String email,
    String password,
  ) async {
    if (url.isEmpty || email.isEmpty || password.isEmpty) {
      VimToast.show(context, context.l10n.onboardingRequiredFields);
      return;
    }
    OnboardingLogger.event('existing server login submitted', {
      'server_host': Uri.tryParse(url)?.host ?? 'invalid',
      'email_domain': email.contains('@') ? email.split('@').last : 'invalid',
    });
    try {
      await context.read<AuthCubit>().login(url, email, password);
    } catch (error) {
      if (context.mounted) {
        final mapped = safeErrorMessage(error);
        VimToast.show(
          context,
          mapped.isNotEmpty ? mapped : context.l10n.onboardingAccessDenied,
          color: context.terminalColors.warning,
        );
      }
    }
  }

  @override
  void disposeAdapter() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    _pocoMessage.dispose();
    _pocoSequence.dispose();
    super.disposeAdapter();
  }
}

class _SetupWatchdog {
  final ValueNotifier<bool> stalled = ValueNotifier(false);
  Timer? _timer;

  void arm(Duration after, VoidCallback onStall) {
    reset();
    _timer = Timer(after, () {
      onStall();
      stalled.value = true;
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    stalled.value = false;
  }

  void dispose() {
    _timer?.cancel();
    stalled.dispose();
  }
}
