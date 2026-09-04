// PlanPanel (plan Task 13 Step 3): renders SessionState.plan (a map with
// an "entries" list, each entry a map with content/priority/status) as a
// simple todo list. Renders nothing when no plan is published yet. The
// panel is intentionally read-only in v1 — there is no up-channel action
// for plan entries in the current contract; the agent pushes a new plan
// snapshot via the reduced state.
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class PlanPanel extends StatelessWidget {
  const PlanPanel({super.key, required this.plan});
  final Map<String, dynamic>? plan;

  @override
  Widget build(BuildContext context) {
    final value = plan;
    if (value == null) return const SizedBox.shrink();
    final entries = (value['entries'] as List?)?.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList() ?? const <Map<String,dynamic>>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    return _buildPanel(context, entries);
  }

  Widget _buildPanel(
    BuildContext context,
    List<Map<String, dynamic>> entries,
  ) {
    final colors = context.colorScheme;

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                context.l10n.agentPlanPanelBadge,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: AppFonts.heavy,
                ),
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  context.l10n.agentPlanPanelLabel,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          VSpace.x2,
          for (final entry in entries) ...[
            _buildEntry(context, entry),
            VSpace.x1,
          ],
        ],
      ),
    );
  }

  Widget _buildEntry(BuildContext context, Map<String, dynamic> entry) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final content = entry['content']?.toString() ?? '';
    final priority = entry['priority']?.toString() ?? '';
    final status = entry['status']?.toString() ?? 'pending';

    final isDone = status == 'completed' || status == 'done';
    final isInProgress = status == 'in_progress' || status == 'in-progress';

    final accent = isDone
        ? colors.primary.withValues(alpha: 0.5)
        : isInProgress
            ? terminalColors.warning
            : colors.onSurface.withValues(alpha: 0.6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: AppSizes.space * 0.5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isDone ? accent : Colors.transparent,
            border: Border.all(color: accent, width: 1.5),
          ),
        ),
        HSpace.x2,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: TextStyle(
                  color: isDone
                      ? colors.onSurface.withValues(alpha: 0.4)
                      : colors.onSurface,
                  fontFamily: AppFonts.family,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              if (priority.isNotEmpty || status.isNotEmpty)
                Text(
                  '[${priority.isNotEmpty ? '${priority.toUpperCase()} · ' : ''}${status.toUpperCase()}]',
                  style: TextStyle(
                    color: accent,
                    fontFamily: AppFonts.family,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
