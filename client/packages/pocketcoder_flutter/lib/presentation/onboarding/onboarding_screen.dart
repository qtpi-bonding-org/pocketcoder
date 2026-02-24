import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../app/bootstrap.dart';
import '../../app_router.dart';
import '../../application/system/auth_cubit.dart';
import '../../application/system/poco_cubit.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/ascii_logo.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/poco_widget.dart';
import '../core/widgets/ui_flow_listener.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset Poco for this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PocoCubit>().reset(
          'WHO GOES THERE? IDENTIFY YOURSELF AND PROVIDE THE SECRET PASSPHRASE.');
      context.read<PocoCubit>().setExpression(PocoExpressions.scanning);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                          _buildTextField(
                            context: context,
                            controller: _emailController,
                            label: 'IDENTITY',
                            hint: 'ENTER EMAIL',
                          ),
                          VSpace.x2,
                          _buildTextField(
                            context: context,
                            controller: _passwordController,
                            label: 'PASSPHRASE',
                            hint: 'ENTER PASSWORD',
                            obscureText: true,
                            onSubmitted: (_) => isLoading
                                ? null
                                : context.read<AuthCubit>().login(
                                      _emailController.text.trim(),
                                      _passwordController.text,
                                    ),
                          ),
                          VSpace.x2,
                          if (isLoading)
                            Text(
                              'AUTHENTICATING...',
                              style: TextStyle(
                                fontFamily: AppFonts.bodyFamily,
                                color: colors.onSurface,
                                fontSize: AppSizes.fontSmall,
                              ),
                            ),
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
                        : () => context.read<AuthCubit>().login(
                              _emailController.text.trim(),
                              _passwordController.text,
                            ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: colors.onSurface.withValues(alpha: 0.7),
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
          ),
        ),
        VSpace.x1,
        TextField(
          controller: controller,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontStandard,
          ),
          cursorColor: colors.onSurface,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontSmall,
            ),
            fillColor: colors.surface,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: colors.onSurface,
              ),
              borderRadius: BorderRadius.zero,
            ),
            contentPadding: EdgeInsets.all(AppSizes.space * 2),
          ),
        ),
      ],
    );
  }
}
