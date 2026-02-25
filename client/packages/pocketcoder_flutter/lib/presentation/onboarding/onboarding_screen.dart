import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController(text: 'http://127.0.0.1:8090');

  @override
  void initState() {
    super.initState();
    // Reset Poco for this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PocoCubit>().reset(
          'WHO GOES THERE? IDENTIFY YOURSELF AND PROVIDE THE SECRET PASSPHRASE.');
      context.read<PocoCubit>().setExpression(PocoExpressions.scanning);
    });

    _checkInitialStatus();
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

  void _handleLogin(AuthCubit cubit) {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      getIt<IAuthRepository>().updateBaseUrl(url);
    }
    cubit.login(
      _emailController.text.trim(),
      _passwordController.text,
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
                'Identity verified! Welcome home. I knew it was you—just had to make sure the Cloud wasn\'t spoofing your signature.',
                sequence: PocoExpressions.happy);
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) context.goNamed(RouteNames.home);
            });
          } else if (state.status == UiFlowStatus.failure) {
            context.read<PocoCubit>().updateMessage(
                state.error?.toString() ?? 'ACCESS DENIED.',
                sequence: PocoExpressions.nervous);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final isLoading = authState.status == UiFlowStatus.loading;
            final colors = context.colorScheme;

            return Scaffold(
              backgroundColor: colors.surface,
              body: ScanlineWidget(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      padding: EdgeInsets.all(AppSizes.space * 4),
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
                          TerminalTextField(
                            controller: _urlController,
                            label: 'HOME SERVER',
                            hint: 'http://127.0.0.1:8090',
                          ),
                          VSpace.x2,
                          TerminalTextField(
                            controller: _emailController,
                            label: 'IDENTITY',
                            hint: 'ENTER EMAIL',
                          ),
                          VSpace.x2,
                          TerminalTextField(
                            controller: _passwordController,
                            label: 'PASSPHRASE',
                            hint: 'ENTER PASSWORD',
                            obscureText: true,
                            onSubmitted: (_) => isLoading
                                ? null
                                : _handleLogin(context.read<AuthCubit>()),
                          ),
                          VSpace.x2,
                          if (isLoading)
                            const TerminalLoadingIndicator(
                                label: 'AUTHENTICATING'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: TerminalFooter(
                actions: [
                  TerminalAction(
                    label: isLoading ? 'PROCESSING...' : 'LOGIN',
                    onTap: isLoading
                        ? () {}
                        : () => _handleLogin(context.read<AuthCubit>()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
