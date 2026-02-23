import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

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
    final colors = context.colorScheme;
    // A single green line to separate footer from content
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.onSurface, width: AppSizes.borderWidth),
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
    final colors = context.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        // The "Inverted" hover effect color
        splashColor: colors.onSurface.withValues(alpha: 0.3),
        highlightColor: colors.onSurface.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
          decoration: BoxDecoration(
            // Adds a subtle divider line between buttons
            border: Border(
              right: BorderSide(
                  color: colors.secondary
                      .withValues(alpha: 0.2), // Adjusted for theme
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
                color: colors.onSurface, // Solid Green Block
                child: Text(
                  action.keyLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.surface, // Black text on Green block
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
                  color: colors.onSurface, // Green text
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
