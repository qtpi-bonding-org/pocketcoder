import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

/// A configuration object for a single footer button
class TerminalAction {
  final String label; // e.g. "HELP"
  final VoidCallback onTap;

  TerminalAction({
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
              return _buildActionButton(context, action);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, TerminalAction action) {
    final colors = context.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        splashColor: colors.onSurface.withValues(alpha: 0.2),
        highlightColor: colors.onSurface.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.1),
                  width: AppSizes.borderWidth),
            ),
          ),
          child: Text(
            action.label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny,
              fontWeight: AppFonts.heavy,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
