import 'package:flutter/material.dart';
import '../../../../design_system/primitives/app_fonts.dart';
import '../../../../design_system/primitives/app_palette.dart';
import '../../../../design_system/primitives/app_sizes.dart';
import '../../../../design_system/primitives/spacers.dart';
import '../../../../domain/permission/permission_request.dart';

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
    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: AppPalette.primary.primaryColor.withValues(alpha: 0.05),
        border: Border.all(
          color: AppPalette.primary.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: AppPalette.primary.primaryColor,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  'GATEKEEPER CHALLENGE',
                  style: TextStyle(
                    color: AppPalette.primary.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          VSpace.x2,
          Text(
            'POCO is requesting permission to:',
            style: TextStyle(
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          VSpace.x1,
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space,
              vertical: AppSizes.space / 2,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${request.permission.toUpperCase()} ${request.metadata['command'] ?? ''}',
              style: TextStyle(
                color: AppPalette.primary.textPrimary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (request.patterns.isNotEmpty) ...[
            VSpace.x2,
            Text(
              'Patterns:',
              style: TextStyle(
                color: AppPalette.primary.textPrimary.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
            ...request.patterns.map((p) => Text(
                  '• $p',
                  style: TextStyle(
                    color:
                        AppPalette.primary.textPrimary.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontFamily: AppFonts.bodyFamily,
                  ),
                )),
          ],
          VSpace.x3,
          Row(
            children: [
              Expanded(
                child: _Button(
                  label: 'DENY',
                  color: Colors.redAccent,
                  onTap: onDeny,
                ),
              ),
              HSpace.x2,
              Expanded(
                child: _Button(
                  label: 'AUTHORIZE',
                  color: AppPalette.primary.primaryColor,
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

class _Button extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
