import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class DeployCredentialsView extends StatefulWidget {
  const DeployCredentialsView({
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
  State<DeployCredentialsView> createState() => _DeployCredentialsViewState();
}

class _DeployCredentialsViewState extends State<DeployCredentialsView> {
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
        title: context.l10n.onboardingServerCredentialsTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        actions: [
          TerminalAction(
              label: context.l10n.actionContinue,
              onTap: widget.isValid ? widget.onContinue : () {},
              emphasis: widget.isValid ? Emphasis.outlined : null),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
              child: Column(
                children: [
                  PocoBubble(
                    message: context.l10n.onboardingDeployCredentialsPoco,
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
          ),
        ),
      );
}
