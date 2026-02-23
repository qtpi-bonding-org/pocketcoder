import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class TerminalInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String prompt;
  final bool enabled;

  const TerminalInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.prompt = '%',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
      decoration: BoxDecoration(
        color: colors.surface,
      ),
      child: Row(
        children: [
          Text(
            '$prompt ',
            style: TextStyle(
              color: enabled ? colors.onSurface : Colors.grey,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Expanded(
            child: TextField(
              enabled: enabled,
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
              ),
              cursorColor: colors.onSurface,
              cursorWidth: AppSizes.fontTiny, // Block style
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
