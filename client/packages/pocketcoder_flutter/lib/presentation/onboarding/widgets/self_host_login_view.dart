import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

class SelfHostLoginView extends StatefulWidget {
  const SelfHostLoginView({
    super.key,
    required this.initialUrl,
    required this.initialEmail,
    required this.initialPassword,
    required this.status,
    required this.pocoMessage,
    required this.pocoSequence,
    required this.pocoHistory,
    required this.onDeploy,
    required this.onLogin,
    this.onRetrySetup,
    this.errorInboxLink,
  });

  final String initialUrl;
  final String initialEmail;
  final String initialPassword;
  final UiFlowStatus status;
  final String pocoMessage;
  final List<(String, int)> pocoSequence;
  final List<String> pocoHistory;
  final VoidCallback onDeploy;
  final Future<void> Function(String url, String email, String password)
      onLogin;
  final VoidCallback? onRetrySetup;
  final Widget? errorInboxLink;

  @override
  State<SelfHostLoginView> createState() => _SelfHostLoginViewState();
}

class _SelfHostLoginViewState extends State<SelfHostLoginView> {
  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.status == UiFlowStatus.loading;
    final signedIn = widget.status == UiFlowStatus.success;
    final onRetrySetup = widget.onRetrySetup;
    return PocketCoderShell(
      showBack: true,
      backFallbackRoute: AppRoutes.onboarding,
      footer: switch ((loading, signedIn, onRetrySetup)) {
        (true, _, _) => WizardFooter(
            busyLabel: context.l10n.onboardingAuthenticating,
          ),
        (_, true, final retry?) => WizardFooter(
            onNext: retry,
            nextLabel: context.l10n.onboardingLoginRetry,
          ),
        (_, true, null) => WizardFooter(
            busyLabel: context.l10n.onboardingLoginFinishingSetup,
          ),
        _ => WizardFooter(onNext: _login),
      },
      body: OnboardingContentShell(
        child: Column(
          children: [
            TerminalConversationTurn(
              speaker: TerminalConversationSpeaker.poco,
              message: widget.pocoMessage,
              sequence: widget.pocoSequence,
              history: widget.pocoHistory,
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
              onSubmitted: (_) => loading || signedIn ? null : _login(),
            ),
            if (widget.errorInboxLink case final link?) ...[VSpace.x3, link],
          ],
        ),
      ),
    );
  }

  Future<void> _login() {
    FocusScope.of(context).unfocus();
    return widget.onLogin(
      _urlController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
  }
}
