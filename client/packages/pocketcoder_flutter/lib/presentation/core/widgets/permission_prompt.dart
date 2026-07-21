// PermissionPrompt (plan Task 13 Step 2): the human-in-the-loop gatekeeper
// surface. Reads the pending SessionState.permission map from
// PermissionState (the new Task 12 shape — `requestId`, `status`, and a
// list of `options` each with `optionId`/`name`/`kind`), and wires
// allow/deny buttons to PermissionCubit.authorize(optionId) / .deny().
// Renders nothing when no permission is pending.
//
// The previous version of this widget took a domain `Permission` object
// from the old transport; that surface is retired (Task 14 deletes its
// cubit + repository). This widget now lives entirely off the
// PermissionState.permission map — no AG-UI / domain types leak in.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'terminal_button.dart';

class PermissionPrompt extends StatelessWidget {
  const PermissionPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionCubit, PermissionState>(
      builder: (context, state) {
        final permission = state.permission;
        if (permission == null) return const SizedBox.shrink();
        return _build(context, permission);
      },
    );
  }

  Widget _build(BuildContext context, Map<String, dynamic> permission) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final status = (permission['status'] as String?) ?? 'pending';
    final rawOptions = permission['options'];
    final options = (rawOptions is List)
        ? rawOptions.whereType<Map>().map((o) => Map<String, dynamic>.from(o)).toList()
        : const <Map<String, dynamic>>[];

    final requestId = (permission['requestId'] as String?) ?? '';
    final toolCall = permission['toolCall'];
    final toolTitle = toolCall is Map ? toolCall['title']?.toString() : null;

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
          Text(
            context.l10n.permissionRequestingLabel(
              (status.isNotEmpty ? status : 'SYSTEM').toUpperCase(),
            ),
            style: TextStyle(
              color: terminalColors.warning.withValues(alpha: 0.8),
              fontSize: AppSizes.fontMini,
              fontWeight: AppFonts.heavy,
            ),
          ),
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
          // For each option we render a row: the option's name (label) and
          // an "AUTHORIZE" terminal button that calls authorize(optionId).
          // If the agent offered zero options, fall back to a single allow
          // button that uses an empty optionId (a permissive default — the
          // backend's permission plumbing accepts optionId as a string).
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
                    onTap: () =>
                        context.read<PermissionCubit>().authorize(''),
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
                      ((option['name'] as String?) ?? '').toUpperCase(),
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
                        .authorize('${option['optionId'] ?? ''}'),
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
