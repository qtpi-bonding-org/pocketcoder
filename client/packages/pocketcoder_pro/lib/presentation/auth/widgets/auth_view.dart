import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

class AuthView extends StatelessWidget {
  const AuthView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onAuthenticate,
    required this.onBack,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onAuthenticate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return TerminalScaffold(
      title: 'CLOUD PROVISIONING AUTH',
      actions: [
        TerminalAction(
          label: isLoading ? 'CONNECTING...' : 'LOGIN VIA LINODE',
          onTap: isLoading ? () {} : onAuthenticate,
        ),
        TerminalAction(label: 'BACK', onTap: onBack),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BiosFrame(
            title: 'OAUTH GATEWAY',
            child: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined, size: 64, color: colors.primary),
                  VSpace.x2,
                  Text(
                    'DEPLOY POCKETCODER',
                    style: TextStyle(
                      fontFamily: AppFonts.headerFamily,
                      fontSize: AppSizes.fontBig,
                      color: colors.onSurface,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  VSpace.x2,
                  Text(
                    'SIGN IN WITH YOUR LINODE ACCOUNT TO PROVISION AN ISOLATED INSTANCE. DATA RETAINMENT REMAINS UNDER YOUR EXCLUSIVE CONTROL.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                  if (isLoading) ...[
                    VSpace.x4,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                        HSpace.x2,
                        Text(
                          'WAITING FOR BROWSER AUTH...',
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.primary,
                            fontSize: AppSizes.fontTiny,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (errorMessage != null) ...[
                    VSpace.x4,
                    Container(
                      padding: EdgeInsets.all(AppSizes.space),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.error),
                        color: colors.error.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: colors.error, size: 16),
                          HSpace.x2,
                          Expanded(
                            child: Text(
                              errorMessage!.toUpperCase(),
                              style: TextStyle(
                                color: colors.error,
                                fontFamily: AppFonts.bodyFamily,
                                fontSize: AppSizes.fontTiny,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
