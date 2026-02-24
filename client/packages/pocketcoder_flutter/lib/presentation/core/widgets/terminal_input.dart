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
    final terminalColors = context.terminalColors;
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
              color: enabled ? terminalColors.attention : Colors.grey,
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
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
                color: terminalColors.attention,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontStandard,
              ),
              cursorColor: terminalColors.attention,
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
