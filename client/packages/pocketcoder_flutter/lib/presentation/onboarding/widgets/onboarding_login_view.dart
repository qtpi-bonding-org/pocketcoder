import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

class OnboardingLoginView extends StatefulWidget {
  const OnboardingLoginView({
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

  @override
  State<OnboardingLoginView> createState() => _OnboardingLoginViewState();
}

class _OnboardingLoginViewState extends State<OnboardingLoginView> {
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
    return PocketCoderShell(
      title: context.l10n.onboardingServerLoginTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      actions: [
        TerminalAction(
          label: loading
              ? context.l10n.onboardingServerConnecting
              : context.l10n.onboardingLogin,
          onTap: loading ? () {} : _login,
          emphasis: Emphasis.outlined,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
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
                  onSubmitted: (_) => loading ? null : _login(),
                ),
                if (loading) ...[
                  VSpace.x2,
                  TerminalLoadingIndicator(
                    label: context.l10n.onboardingAuthenticating,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() => widget.onLogin(
        _urlController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
}
