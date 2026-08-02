import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import '../../app_router.dart';

enum _OnboardingMode { login, deploy }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingMode _mode = _OnboardingMode.login;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset Poco for this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PocoCubit>().reset(
          context.l10n.onboardingPocoChallengeMessage);
      context.read<PocoCubit>().setExpression(PocoExpressions.scanning);
    });

    final prefill = widget.prefill;
    if (prefill != null) {
      _urlController.text = prefill.url;
      _emailController.text = prefill.email;
      _passwordController.text = prefill.password;
    } else {
      _urlController.text = 'http://127.0.0.1:8090';
      _restoreSavedUrl();
    }
    _checkInitialStatus();
  }

  Future<void> _restoreSavedUrl() async {
    final saved = await getIt<FlutterSecureStorage>().read(key: 'pb_server_url');
    if (saved != null && mounted) {
      _urlController.text = saved;
    }
  }

  Future<void> _checkInitialStatus() async {
    await getIt<IStatusRepository>().checkPocketBaseHealth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AuthCubit cubit) async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      await getIt<IAuthRepository>().updateBaseUrl(url);
    }
    cubit.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  void _handleDeploy() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      return;
    }
    context.pushNamed(
      RouteNames.deploy,
      extra: DeployCredentials(email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthCubit>(),
      child: UiFlowListener<AuthCubit, AuthState>(
        autoDismissLoading: false, // We handle loading state manually with Poco
        listener: (context, state) {
          if (state.status == UiFlowStatus.loading) {
            context.read<PocoCubit>().setExpression(PocoExpressions.scanning);
          } else if (state.status == UiFlowStatus.success) {
            context.read<PocoCubit>().updateMessage(
                context.l10n.onboardingPocoWelcome,
                sequence: PocoExpressions.happy);
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) context.goNamed(RouteNames.home);
            });
          } else if (state.status == UiFlowStatus.failure) {
            context.read<PocoCubit>().updateMessage(
                state.error?.toString() ?? context.l10n.onboardingAccessDenied,
                sequence: PocoExpressions.nervous);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final isLoading = authState.status == UiFlowStatus.loading;

            return TerminalScaffold(
              title: context.l10n.onboardingTitle,
              showHeader: false, // Onboarding has its own layout
              actions: [
                TerminalAction(
                  label: isLoading
                      ? context.l10n.onboardingProcessing
                      : (_mode == _OnboardingMode.login ? 'LOGIN' : 'DEPLOY'),
                  onTap: isLoading
                      ? () {}
                      : (_mode == _OnboardingMode.login
                          ? () => _handleLogin(context.read<AuthCubit>())
                          : _handleDeploy),
                ),
              ],
              body: Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: EdgeInsets.symmetric(vertical: AppSizes.space * 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AsciiLogo(
                          text: AppAscii.pocketCoderLogo,
                          fontSize: AppSizes.fontTiny,
                        ),
                        VSpace.x8,
                        PocoWidget(pocoSize: AppSizes.fontLarge),
                        VSpace.x4,
                        SegmentedButton<_OnboardingMode>(
                          segments: const [
                            ButtonSegment(
                              value: _OnboardingMode.login,
                              label: Text('LOGIN'),
                            ),
                            ButtonSegment(
                              value: _OnboardingMode.deploy,
                              label: Text('DEPLOY'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (selected) {
                            setState(() => _mode = selected.first);
                          },
                        ),
                        VSpace.x4,
                        if (_mode == _OnboardingMode.login) ...[
                          TerminalTextField(
                            controller: _urlController,
                            label: context.l10n.onboardingHomeServer,
                            hint: 'http://127.0.0.1:8090',
                          ),
                          VSpace.x2,
                        ],
                        TerminalTextField(
                          key: const Key('deployEmailField'),
                          controller: _emailController,
                          label: context.l10n.onboardingIdentityLabel,
                          hint: context.l10n.onboardingEmailHint,
                        ),
                        VSpace.x2,
                        TerminalTextField(
                          controller: _passwordController,
                          label: context.l10n.onboardingPassphraseLabel,
                          hint: context.l10n.onboardingPasswordHint,
                          obscureText: true,
                          onSubmitted: (_) => isLoading
                              ? null
                              : (_mode == _OnboardingMode.login
                                  ? _handleLogin(context.read<AuthCubit>())
                                  : _handleDeploy()),
                        ),
                        VSpace.x2,
                        if (isLoading)
                          TerminalLoadingIndicator(
                              label: context.l10n.onboardingAuthenticating),
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
