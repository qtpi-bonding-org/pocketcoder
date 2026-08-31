// PermissionCard is the human-in-the-loop gatekeeper surface rendered inline
// in the message timeline. It is deliberately Cubit-free: the adapter owns
// permission side effects and supplies this view's callback.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key, required this.item, required this.onSelect});

  final PermissionRequestTimelineItem item;
  final void Function(String requestId, {String? optionId, bool cancelled})
      onSelect;

  @override
  Widget build(BuildContext context) {
    return _build(context, item);
  }

  Widget _build(
      BuildContext context, PermissionRequestTimelineItem permission) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final options = permission.options;

    final requestId = permission.requestId;
    // toolTitle is ACP's ToolCallUpdate.Title, optional on the wire -- a
    // harness (goose, seen live) can omit it entirely for a given tool
    // call. Without a fallback this card showed nothing but its own
    // internal request UUID, with no indication at all of what it was
    // actually asking permission for.
    final toolTitle = permission.toolTitle ??
        permission.description ??
        context.l10n.permissionRequestedFallback;

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
              Text(
                'SECURITY',
                style: TextStyle(
                  color: terminalColors.warning,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
              HSpace.x1,
              Expanded(
                child: Text(
                  context.l10n.permissionSignoffTitle,
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
          if (toolTitle.isNotEmpty) ...[
            VSpace.x1,
            Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.4),
                border: Border.all(
                  color: terminalColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      toolTitle,
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
          ],
          if (requestId.isNotEmpty) ...[
            VSpace.x1,
            Text(
              '[$requestId]',
              style: TextStyle(
                color: terminalColors.warning.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          VSpace.x3,
          if (options.isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TerminalButton(
                label: context.l10n.actionDeny,
                isPrimary: false,
                color: terminalColors.warning,
                onTap: () => onSelect(requestId, cancelled: true),
              ),
            )
          else
            Wrap(
              spacing: AppSizes.space,
              runSpacing: AppSizes.space,
              children: [
                for (final option in options)
                  TerminalButton(
                    label: option.label,
                    onTap: () => onSelect(
                      requestId,
                      optionId: option.optionId,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
