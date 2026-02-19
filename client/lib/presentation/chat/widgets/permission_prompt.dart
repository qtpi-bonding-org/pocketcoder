import 'package:flutter/material.dart';
import '../../../../design_system/theme/app_theme.dart';
import '../../../../domain/permission/permission_request.dart';
import '../../core/widgets/terminal_dialog.dart'; // For TerminalButton

class PermissionPrompt extends StatelessWidget {
  final PermissionRequest request;
  final VoidCallback onAuthorize;
  final VoidCallback onDeny;

  const PermissionPrompt({
    super.key,
    required this.request,
    required this.onAuthorize,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: colors.primary,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  'GATEKEEPER CHALLENGE',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          VSpace.x2,
          Text(
            '${(request.source ?? "SYSTEM").toUpperCase()} IS REQUESTING PERMISSION:',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.7),
              fontSize: AppSizes.fontMini,
              fontWeight: AppFonts.heavy,
            ),
          ),
          VSpace.x1,
          Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.4),
              border:
                  Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${request.permission.toUpperCase()} ${request.metadata?['command'] ?? ''}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: AppFonts.bodyFamily,
                      fontSize: AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((request.patterns ?? []).isNotEmpty) ...[
            VSpace.x2,
            Text(
              'Patterns:',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
            ...(request.patterns ?? []).map((p) => Text(
                  '• $p',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.8),
                    fontSize: AppSizes.fontTiny,
                    fontFamily: AppFonts.bodyFamily,
                  ),
                )),
          ],
          VSpace.x3,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: 'DENY',
                  isPrimary: false,
                  onTap: onDeny,
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: 'AUTHORIZE',
                  onTap: onAuthorize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
