import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class OnboardingLoginScreen extends StatefulWidget {
  const OnboardingLoginScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  State<OnboardingLoginScreen> createState() => _OnboardingLoginScreenState();
}

class _OnboardingLoginScreenState extends State<OnboardingLoginScreen> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      _urlController.text = prefill.url;
      _emailController.text = prefill.email;
      _passwordController.text = prefill.password;
    } else {
      _urlController.text = 'http://127.0.0.1:8090';
      _restoreSavedUrl();
    }
  }

  Future<void> _restoreSavedUrl() async {
    final saved =
        await getIt<FlutterSecureStorage>().read(key: 'pb_server_url');
    if (saved != null && mounted) _urlController.text = saved;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(AuthCubit cubit) async {
    final url = _urlController.text.trim();
    if (url.isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.onboardingRequiredFields)),
      );
      return;
    }
    OnboardingLogger.event('existing server login submitted', {
      'server_host': Uri.tryParse(url)?.host ?? 'invalid',
      'email_domain': _emailController.text.contains('@')
          ? _emailController.text.trim().split('@').last
          : 'invalid',
    });
    try {
      await getIt<IAuthRepository>().updateBaseUrl(url);
      await cubit.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == UiFlowStatus.success) {
            OnboardingLogger.event(
                'existing server connected; opening harness choice');
            context.read<PocoCubit>().setExpression(PocoExpressions.happy);
            context.goNamed(RouteNames.onboardingHarnessAuth);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final loading = state.status == UiFlowStatus.loading;
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
                  onTap:
                      loading ? () {} : () => _login(context.read<AuthCubit>()),
                ),
              ],
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
                    child: Column(
                      children: [
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
                          onSubmitted: (_) => loading
                              ? null
                              : _login(context.read<AuthCubit>()),
                        ),
                        if (loading) ...[
                          VSpace.x2,
                          TerminalLoadingIndicator(
                              label: context.l10n.onboardingAuthenticating),
                        ],
                        if (state.error != null) ...[
                          VSpace.x2,
                          Text(
                            state.error.toString(),
                            style: TextStyle(color: context.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
