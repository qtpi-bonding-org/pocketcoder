import 'package:flutter/material.dart';
import '../../../design_system/primitives/app_fonts.dart';
import '../../../design_system/primitives/app_palette.dart';
import '../../../design_system/primitives/app_sizes.dart';
import '../../../design_system/primitives/spacers.dart';

/// A configuration object for a single footer button
class TerminalAction {
  final String keyLabel; // e.g. "F1"
  final String label; // e.g. "HELP"
  final VoidCallback onTap;

  TerminalAction({
    required this.keyLabel,
    required this.label,
    required this.onTap,
  });
}

class TerminalFooter extends StatelessWidget {
  final List<TerminalAction> actions;

  const TerminalFooter({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // A single green line to separate footer from content
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.primary.backgroundPrimary,
        border: Border(
          top: BorderSide(
              color: AppPalette.primary.textPrimary,
              width: AppSizes.borderWidth),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions.map((action) {
              return _buildFKeyButton(context, action);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFKeyButton(BuildContext context, TerminalAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        // The "Inverted" hover effect color (using Cyberpunk Green)
        splashColor: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
        highlightColor: AppPalette.primary.textPrimary.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
          decoration: BoxDecoration(
            // Adds a subtle divider line between buttons
            border: Border(
              right: BorderSide(
                  color: AppPalette.primary.textSecondary,
                  width: AppSizes.borderWidth),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The "F-Key" part (Inverted block look)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.space * 0.5, vertical: 0),
                color: AppPalette.primary.textPrimary, // Solid Green Block
                child: Text(
                  action.keyLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: AppPalette
                        .primary.backgroundPrimary, // Black text on Green block
                    fontSize: AppSizes.fontBig,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
              ),
              HSpace.x1,
              // The Label part
              Text(
                action.label,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: AppPalette.primary.textPrimary, // Green text
                  fontSize: AppSizes.fontBig,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
