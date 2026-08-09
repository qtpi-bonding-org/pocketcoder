import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_value_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import '../../../app_router.dart';

class OnboardingLoginAdapter extends CubitAdapter<AuthCubit, AuthState> {
  OnboardingLoginAdapter({super.key, this.prefill});

  final OnboardingPrefill? prefill;
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pocoMessage = ValueNotifier<String>('');
  final _pocoSequence = ValueNotifier<List<(String, int)>>(
    const <(String, int)>[],
  );
  final _pocoHistory = ValueNotifier<List<String>>(const <String>[]);

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
      builder: (context, status, _) => _buildScaffold(context, status),
    );
  }

  void _initialize(BuildContext context) {
    if (_pocoMessage.value.isNotEmpty) return;
    _urlController.text = prefill?.url ?? 'http://127.0.0.1:8090';
    _emailController.text = prefill?.email ?? '';
    _passwordController.text = prefill?.password ?? '';
    _pocoMessage.value = context.l10n.onboardingPocoChallengeMessage;
    _pocoSequence.value = PocoExpressions.scanning;
    final savedUrl = context.read<AuthCubit>().state.savedUrl;
    if (prefill == null && savedUrl != null) _urlController.text = savedUrl;
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
      _pocoMessage.value =
          state.error?.toString() ?? context.l10n.onboardingAccessDenied;
      _pocoSequence.value = PocoExpressions.nervous;
    }
  }

  Future<void> _login(BuildContext context) async {
    final url = _urlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
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
        VimToast.show(context, error.toString(),
            color: context.colorScheme.error);
      }
    }
  }

  Widget _buildScaffold(BuildContext context, UiFlowStatus status) {
    final loading = status == UiFlowStatus.loading;
    return TerminalScaffold(
      title: context.l10n.onboardingServerLoginTitle,
      actions: [
        TerminalAction(
          label: context.l10n.actionBack,
          onTap: () => AppNavigation.back(context),
        ),
        TerminalAction(
          label: context.l10n.onboardingDeploy,
          onTap: () => context.pushNamed(RouteNames.onboardingDeploy),
        ),
        TerminalAction(
          label: loading
              ? context.l10n.onboardingServerConnecting
              : context.l10n.onboardingLogin,
          onTap: loading ? () {} : () => _login(context),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
            child: Column(
              children: [
                PocoValueWidget(
                  message: _pocoMessage,
                  sequence: _pocoSequence,
                  history: _pocoHistory,
                  pocoSize: AppSizes.fontLarge,
                ),
                VSpace.x4,
                TerminalTextField(
                  controller: _urlController,
                  label: context.l10n.onboardingServerUrl,
                  hint: context.l10n.onboardingServerUrlHint,
                ),
                VSpace.x2,
                TerminalTextField(
                  controller: _emailController,
                  label: context.l10n.onboardingEmail,
                  hint: context.l10n.onboardingEmailHintShort,
                ),
                VSpace.x2,
                TerminalTextField(
                  controller: _passwordController,
                  label: context.l10n.onboardingPassword,
                  obscureText: true,
                  onSubmitted: (_) => loading ? null : _login(context),
                ),
                if (loading) ...[
                  VSpace.x2,
                  TerminalLoadingIndicator(
                      label: context.l10n.onboardingAuthenticating),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void disposeAdapter() {
    super.disposeAdapter();
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pocoMessage.dispose();
    _pocoSequence.dispose();
    _pocoHistory.dispose();
  }
}
