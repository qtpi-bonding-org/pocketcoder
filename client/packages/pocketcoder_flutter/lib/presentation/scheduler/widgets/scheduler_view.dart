import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';

import 'scheduler_dialogs.dart';

class SchedulerView extends StatelessWidget {
  const SchedulerView(
      {super.key,
      required this.state,
      required this.onPause,
      required this.onUnpause,
      required this.onRunNow,
      required this.onDelete,
      required this.onRename,
      required this.onUpdateCron,
      required this.onCreate});

  final SchedulerState state;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onUnpause;
  final ValueChanged<String> onRunNow;
  final ValueChanged<String> onDelete;
  final Future<void> Function({required String id, required String displayName})
      onRename;
  final Future<void> Function({required String id, required String cron})
      onUpdateCron;
  final Future<void> Function(
      {required String displayName,
      required String cron,
      required String prompt}) onCreate;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        title: context.l10n.schedulerTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        body: BiosFrame(
            title: context.l10n.schedulerRegistryTitle,
            child: Builder(builder: (context) {
              if (state.status == UiFlowStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == UiFlowStatus.failure) {
                return Center(
                    child: TerminalText(safeErrorMessage(state.error),
                        role: TextRole.warn));
              }
              if (state.status != UiFlowStatus.success) {
                return const SizedBox.shrink();
              }
              final schedules = state.schedules;
              return ListView(children: [
                Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: TerminalButton(
                        label: context.l10n.schedulerAddButton,
                        onTap: () => showAddScheduleDialog(context, onCreate))),
                for (final schedule in schedules)
                  _buildScheduleItem(context, schedule),
                if (schedules.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space * 4),
                      child: TerminalText(
                        context.l10n.schedulerNoSchedules,
                        role: TextRole.body,
                      ),
                    ),
                  ),
              ]);
            })));
  }

  Widget _buildScheduleItem(BuildContext context, ScheduleOwner schedule) {
    final paused = schedule.paused ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
          label: schedule.displayName,
          value: schedule.cron ?? '',
          hasBadge: paused),
      VSpace.x1,
      BiosActionStrip(actions: [
        BiosActionStripItem(
            label: paused
                ? context.l10n.schedulerResumeButton
                : context.l10n.schedulerPauseButton,
            onTap: () =>
                paused ? onUnpause(schedule.id) : onPause(schedule.id)),
        BiosActionStripItem(
            label: context.l10n.schedulerRunNowButton,
            onTap: () => onRunNow(schedule.id)),
        BiosActionStripItem(
            label: context.l10n.schedulerEditButton,
            onTap: () => showEditScheduleDialog(
                context, schedule, onRename, onUpdateCron)),
        BiosActionStripItem(
            label: context.l10n.schedulerDeleteButton,
            // Schedules can be recreated, so deletion is warning-level here.
            color: context.terminalColors.warning,
            onTap: () => onDelete(schedule.id)),
      ]),
      VSpace.x2,
    ]);
  }
}
