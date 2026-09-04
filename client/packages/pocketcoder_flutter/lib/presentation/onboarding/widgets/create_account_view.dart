import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';

class CreateAccountView extends StatefulWidget {
  const CreateAccountView({
    super.key,
    required this.email,
    required this.password,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.isValid,
    required this.onContinue,
    this.passwordErrorText,
  });

  final String email;
  final String password;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final bool isValid;
  final VoidCallback onContinue;
  final String? passwordErrorText;

  @override
  State<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<CreateAccountView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _passwordController = TextEditingController(text: widget.password);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        footer: WizardFooter(
            step: 3,
            totalSteps: 6,
            onNext: widget.isValid ? widget.onContinue : () {}),
        showBack: true,
        backFallbackRoute: AppRoutes.onboarding,
        body: OnboardingContentShell(
          child: Column(
            children: [
              PocoBubble(
                message: context.l10n.onboardingServerCredentialsPoco,
              ),
              VSpace.x3,
              TerminalTextField(
                controller: _emailController,
                label: context.l10n.onboardingPocketbaseAdminEmail,
                hint: context.l10n.onboardingEmailHintShort,
                onChanged: widget.onEmailChanged,
              ),
              VSpace.x2,
              TerminalTextField(
                controller: _passwordController,
                label: context.l10n.onboardingPocketbaseAdminPassword,
                obscureText: true,
                onChanged: widget.onPasswordChanged,
                onSubmitted: (_) => widget.onContinue(),
                errorText: widget.passwordErrorText,
              ),
            ],
          ),
        ),
      );
}
