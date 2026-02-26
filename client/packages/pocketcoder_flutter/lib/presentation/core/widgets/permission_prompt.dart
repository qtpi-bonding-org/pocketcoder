import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'terminal_button.dart';

class PermissionPrompt extends StatelessWidget {
  final Permission request;
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

    final terminalColors = context.terminalColors;

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: terminalColors.warning.withValues(alpha: 0.05),
        border: Border.all(
          color: terminalColors.warning.withValues(alpha: 0.3),
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
                color: terminalColors.warning,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  "COMMANDER'S SIGNOFF",
                  style: TextStyle(
                    color: terminalColors.warning,
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
            '${(request.source == "relay-go" ? "POCO" : request.source ?? "SYSTEM").toUpperCase()} IS REQUESTING PERMISSION:',
            style: TextStyle(
              color: terminalColors.warning.withValues(alpha: 0.8),
              fontSize: AppSizes.fontMini,
              fontWeight: AppFonts.heavy,
            ),
          ),
          VSpace.x1,
          Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.4),
              border: Border.all(
                  color: terminalColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${request.permission.toUpperCase()} ${request.metadata?['command'] ?? ''}',
                    style: TextStyle(
                      color: terminalColors.warning,
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
                color: terminalColors.warning.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
            ...(request.patterns ?? []).map((p) => Text(
                  '> $p',
                  style: TextStyle(
                    color: terminalColors.attention,
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
                  color: terminalColors.danger,
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
