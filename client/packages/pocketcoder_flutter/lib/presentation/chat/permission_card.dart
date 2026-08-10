// PermissionCard: the human-in-the-loop gatekeeper surface, now rendered
// inline in the message timeline (Builders.customMessageBuilder for
// metadata['kind'] == 'permission') instead of as a standalone banner below
// the list. Renamed from presentation/core/widgets/permission_prompt.dart's
// PermissionPrompt -- internals unchanged, it already reads 100% of its
// data from PermissionCubit (the CustomMessage passed to
// customMessageBuilder is just a "render here" position marker, see
// PermissionTimelineItem in domain/agent/conversation.dart).
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key, required this.item});

  final PermissionRequestTimelineItem item;

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
    final toolTitle = permission.toolTitle;

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
          if (toolTitle != null && toolTitle.isNotEmpty) ...[
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
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.actionDeny,
                    isPrimary: false,
                    color: terminalColors.danger,
                    onTap: () => context.read<PermissionCubit>().deny(),
                  ),
                ),
                HSpace.x2,
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.actionAuthorize,
                    onTap: () => context.read<PermissionCubit>().authorize(''),
                  ),
                ),
              ],
            )
          else
            for (final option in options) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label.toUpperCase(),
                      style: TextStyle(
                        color: terminalColors.attention,
                        fontFamily: AppFonts.bodyFamily,
                        fontSize: AppSizes.fontStandard,
                      ),
                    ),
                  ),
                  TerminalButton(
                    label: context.l10n.actionAuthorize,
                    onTap: () => context
                        .read<PermissionCubit>()
                        .authorize(option.optionId),
                  ),
                ],
              ),
              VSpace.x1,
            ],
          VSpace.x1,
          TerminalButton(
            label: context.l10n.actionDeny,
            isPrimary: false,
            color: terminalColors.danger,
            onTap: () => context.read<PermissionCubit>().deny(),
          ),
        ],
      ),
    );
  }
}
