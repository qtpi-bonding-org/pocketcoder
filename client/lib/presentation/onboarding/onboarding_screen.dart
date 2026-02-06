import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../app_router.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../../application/system/auth_cubit.dart';
import '../../application/system/poco_cubit.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/ascii_logo.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/poco_widget.dart';
import '../../app/bootstrap.dart';

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
      child: BlocListener<AuthCubit, AuthState>(
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

            return Scaffold(
              backgroundColor: AppPalette.primary.backgroundPrimary,
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
                            controller: _emailController,
                            label: 'IDENTITY',
                            hint: 'ENTER EMAIL',
                          ),
                          VSpace.x2,
                          _buildTextField(
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
                                color: AppPalette.primary.textPrimary,
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
                    keyLabel: 'F1',
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
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.7),
            fontSize: AppSizes.fontTiny,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: AppPalette.primary.textPrimary,
            fontSize: AppSizes.fontStandard,
          ),
          cursorColor: AppPalette.primary.primaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
            ),
            fillColor: Colors.black,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppPalette.primary.primaryColor.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppPalette.primary.primaryColor,
              ),
              borderRadius: BorderRadius.zero,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
