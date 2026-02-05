import 'package:flutter/material.dart';
import '../../../design_system/primitives/app_fonts.dart';
import '../../../design_system/primitives/app_palette.dart';
import '../../../design_system/primitives/app_sizes.dart';

class TerminalInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String prompt;

  const TerminalInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.prompt = '%',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
      decoration: BoxDecoration(
        color: AppPalette.primary.backgroundPrimary,
      ),
      child: Row(
        children: [
          Text(
            '$prompt ',
            style: TextStyle(
              color: AppPalette.primary.textPrimary,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                color: AppPalette.primary.textPrimary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
              ),
              cursorColor: AppPalette.primary.textPrimary,
              cursorWidth: AppSizes.fontTiny, // Block style
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
