import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class OnboardingDeployCredentialsScreen extends StatefulWidget {
  const OnboardingDeployCredentialsScreen({super.key});

  @override
  State<OnboardingDeployCredentialsScreen> createState() =>
      _OnboardingDeployCredentialsScreenState();
}

class _OnboardingDeployCredentialsScreenState
    extends State<OnboardingDeployCredentialsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      OnboardingLogger.event('deployment credentials validation failed');
      VimToast.show(context, context.l10n.onboardingRequiredFields);
      return;
    }
    OnboardingLogger.event('deployment credentials accepted', {
      'email_domain': email.contains('@') ? email.split('@').last : 'invalid',
    });
    context.pushNamed(
      RouteNames.deploy,
      extra: DeployCredentials(email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: context.l10n.onboardingDeployTitle,
      actions: [
        TerminalAction(
            label: context.l10n.actionBack,
            onTap: () => AppNavigation.back(context)),
        TerminalAction(label: context.l10n.actionContinue, onTap: _continue),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
            child: Column(
              children: [
                TerminalTextField(
                  controller: _emailController,
                  label: context.l10n.onboardingPocketbaseAdminEmail,
                  hint: context.l10n.onboardingEmailHintShort,
                ),
                VSpace.x2,
                TerminalTextField(
                  controller: _passwordController,
                  label: context.l10n.onboardingPocketbaseAdminPassword,
                  obscureText: true,
                  onSubmitted: (_) => _continue(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
