import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/ascii_logo.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/typewriter_text.dart';
import '../../app/bootstrap.dart';
import '../../domain/auth/i_auth_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<IAuthRepository>();
      // TODO: Configure repo with _urlController.text if needed

      final success = await repo.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          context.goNamed(RouteNames.home);
        } else {
          setState(() {
            _errorMessage = 'ACCESS DENIED. CHECK CREDENTIALS.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'SYSTEM ERROR: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  PocoAnimator(fontSize: AppSizes.fontLarge),
                  VSpace.x2,
                  TypewriterText(
                    text:
                        'WHO GOES THERE? IDENTIFY YOURSELF AND PROVIDE THE SECRET PASSPHRASE.',
                    speed: const Duration(milliseconds: 60),
                    style: TextStyle(
                      fontFamily: AppFonts.headerFamily,
                      color: AppPalette.primary.textPrimary,
                      fontSize: AppSizes.fontStandard,
                      letterSpacing: 2,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  VSpace.x4,
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: AppPalette.primary.errorColor,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                    VSpace.x2,
                  ],
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
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  VSpace.x2,
                  if (_isLoading)
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
            label: _isLoading ? 'PROCESSING...' : 'LOGIN',
            onTap: _isLoading ? () {} : _handleLogin,
          ),
        ],
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
            fontFamily: AppFonts.bodyFamily,
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.7),
            fontSize: AppSizes.fontTiny,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppSizes.space * 0.5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: AppPalette.primary.textPrimary,
            fontSize: AppSizes.fontStandard,
            height: 1.5,
          ),
          cursorColor: AppPalette.primary.textPrimary,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixText: '\$ ',
            prefixStyle: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: AppPalette.primary.textPrimary,
              fontSize: AppSizes.fontStandard,
              fontWeight: FontWeight.bold,
            ),
            hintStyle: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
              fontSize: AppSizes.fontStandard,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppPalette.primary.textPrimary,
                width: 2,
              ),
              borderRadius: BorderRadius.zero,
            ),
            contentPadding: EdgeInsets.all(AppSizes.space),
            filled: false,
          ),
        ),
      ],
    );
  }
}
