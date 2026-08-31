import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/self_host_login_view.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import '../../../app_router.dart';

class SelfHostLoginAdapter extends CubitAdapter<AuthCubit, AuthState> {
  SelfHostLoginAdapter({super.key, this.prefill});

  final OnboardingPrefill? prefill;
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
    adapter.listenTo(#authStatus, status, () => _handleAuthStatus(context));
    _initialize(context);

    return ValueListenableBuilder<UiFlowStatus>(
      valueListenable: status,
      builder: (context, status, _) => SelfHostLoginView(
        initialUrl: _url.value,
        initialEmail: _email.value,
        initialPassword: _password.value,
        status: status,
        pocoMessage: _pocoMessage.value,
        pocoSequence: _pocoSequence.value,
        pocoHistory: _pocoHistory,
        onDeploy: () => context.pushNamed(RouteNames.onboardingWelcome),
        onLogin: (url, email, password) =>
            _login(context, url, email, password),
      ),
    );
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

  void _handleAuthStatus(BuildContext context) {
    final state = context.read<AuthCubit>().state;
    if (state.status == UiFlowStatus.loading) {
      _pocoSequence.value = PocoExpressions.scanning;
    } else if (state.status == UiFlowStatus.success) {
      OnboardingLogger.event(
          'existing server connected; opening harness choice');
      _pocoMessage.value = context.l10n.onboardingPocoWelcome;
      _pocoSequence.value = PocoExpressions.happy;
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) context.goNamed(RouteNames.onboardingHarnessAuth);
      });
    } else if (state.status == UiFlowStatus.failure) {
      // Never surfaces state.error's raw text -- it may carry an
      // unpredictable underlying exception (network, decoding, etc.) that
      // client/AGENTS.md requires stay out of user-facing copy.
      _pocoMessage.value = context.l10n.onboardingAccessDenied;
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
    } catch (_) {
      if (context.mounted) {
        VimToast.show(context, context.l10n.onboardingAccessDenied,
            color: context.terminalColors.warning);
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
