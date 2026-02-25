import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;

  const TerminalTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
            package: 'pocketcoder_flutter',
          ),
        ),
        VSpace.x1,
        TextField(
          controller: controller,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            package: 'pocketcoder_flutter',
            color: colors.onSurface,
            fontSize: AppSizes.fontStandard,
          ),
          cursorColor: colors.onSurface,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
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
            isDense: true,
          ),
        ),
      ],
    );
  }
}
