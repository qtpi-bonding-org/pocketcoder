import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/domain/scheduler/friendly_schedule.dart';
import 'package:pocketcoder_flutter/domain/scheduler/schedule_timezone.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_choice_list.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

String _formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// [FriendlySchedule] in the device's local wall-clock time -- what the
/// picker shows and what the user edits. Only converted to/from the UTC a
/// cron string actually encodes at the two boundaries: [_localFromCron]
/// when loading an existing schedule, [_cronFromLocal] when saving one.
/// Hourly has no time-of-day component, so it needs no conversion.
FriendlySchedule _localFromCron(String? cron) {
  final utc = FriendlySchedule.tryParseCron(cron ?? '');
  if (utc == null) {
    return FriendlySchedule(frequency: ScheduleFrequency.daily);
  }
  if (utc.frequency == ScheduleFrequency.hourly) return utc;
  final local = utcToLocal(ScheduleLocalTime(
    hour: utc.hour,
    minute: utc.minute,
    daysOfWeek: utc.daysOfWeek,
  ));
  return FriendlySchedule(
    frequency: utc.frequency,
    hour: local.hour,
    minute: local.minute,
    daysOfWeek: local.daysOfWeek,
  );
}

String _cronFromLocal(FriendlySchedule local) {
  if (local.frequency == ScheduleFrequency.hourly) return local.toCron();
  final utc = localToUtc(ScheduleLocalTime(
    hour: local.hour,
    minute: local.minute,
    daysOfWeek: local.daysOfWeek,
  ));
  return FriendlySchedule(
    frequency: local.frequency,
    hour: utc.hour,
    minute: utc.minute,
    daysOfWeek: utc.daysOfWeek,
  ).toCron();
}

/// The frequency + day + time picker shared by the add and edit dialogs.
/// [schedule] is always in local time (see [_localFromCron]/
/// [_cronFromLocal]) -- callers convert to UTC only when building the cron
/// string to save.
class _ScheduleFields extends StatelessWidget {
  const _ScheduleFields({required this.schedule, required this.onChanged});

  final FriendlySchedule schedule;
  final ValueChanged<FriendlySchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final dayOptions = [
      (0, context.l10n.schedulerDaySun),
      (1, context.l10n.schedulerDayMon),
      (2, context.l10n.schedulerDayTue),
      (3, context.l10n.schedulerDayWed),
      (4, context.l10n.schedulerDayThu),
      (5, context.l10n.schedulerDayFri),
      (6, context.l10n.schedulerDaySat),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText(context.l10n.schedulerFrequencyLabel.toLowerCase(),
            role: TextRole.body),
        VSpace.x1,
        TerminalChoiceList<ScheduleFrequency>(
          value: schedule.frequency,
          options: [
            (ScheduleFrequency.hourly, context.l10n.schedulerFrequencyHourly),
            (ScheduleFrequency.daily, context.l10n.schedulerFrequencyDaily),
            (ScheduleFrequency.weekly, context.l10n.schedulerFrequencyWeekly),
          ],
          onSelected: (frequency) {
            if (frequency == ScheduleFrequency.weekly) {
              onChanged(FriendlySchedule(
                frequency: frequency,
                hour: schedule.hour,
                minute: schedule.minute,
                daysOfWeek:
                    schedule.daysOfWeek.isEmpty ? {1} : schedule.daysOfWeek,
              ));
            } else {
              onChanged(FriendlySchedule(
                frequency: frequency,
                hour: schedule.hour,
                minute: schedule.minute,
              ));
            }
          },
        ),
        if (schedule.frequency == ScheduleFrequency.weekly) ...[
          VSpace.x2,
          TerminalText(context.l10n.schedulerDaysLabel.toLowerCase(),
              role: TextRole.body),
          VSpace.x1,
          TerminalMultiChoiceList<int>(
            selected: schedule.daysOfWeek,
            options: dayOptions,
            onChanged: (days) => onChanged(FriendlySchedule(
              frequency: schedule.frequency,
              hour: schedule.hour,
              minute: schedule.minute,
              daysOfWeek: days,
            )),
          ),
        ],
        if (schedule.frequency != ScheduleFrequency.hourly) ...[
          VSpace.x2,
          DetailRow(
            label:
                '${context.l10n.schedulerTimeLabel} (${currentUtcOffsetLabel()})',
            value: _formatTime(schedule.hour, schedule.minute),
            affordance: RowAffordance.expand,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: schedule.hour, minute: schedule.minute),
                initialEntryMode: TimePickerEntryMode.input,
                helpText: context.l10n.schedulerTimeLabel.toUpperCase(),
              );
              if (picked == null) return;
              onChanged(FriendlySchedule(
                frequency: schedule.frequency,
                hour: picked.hour,
                minute: picked.minute,
                daysOfWeek: schedule.daysOfWeek,
              ));
            },
          ),
        ],
      ],
    );
  }
}

void showEditScheduleDialog(
  BuildContext context,
  ScheduleOwner schedule,
  Future<void> Function({required String id, required String displayName})
      onRename,
  Future<void> Function({required String id, required String cron})
      onUpdateCron,
) {
  final nameController = TextEditingController(text: schedule.displayName);
  var friendly = _localFromCron(schedule.cron);

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setState) => TerminalDialog(
        title: context.l10n
            .schedulerEditDialogTitle(
              schedule.displayName,
            )
            .toLowerCase(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.schedulerNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            _ScheduleFields(
              schedule: friendly,
              onChanged: (next) => setState(() => friendly = next),
            ),
          ],
        ),
        actions: [
          TerminalDialogActions(
            actions: [
              TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
                  () => Navigator.of(dialogContext).pop()),
              TerminalActionSpec(
                context.l10n.schedulerSaveButton,
                ActionKind.primary,
                () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final cron = _cronFromLocal(friendly);
                  if (name != schedule.displayName) {
                    onRename(id: schedule.id, displayName: name);
                  }
                  if (cron != (schedule.cron ?? '')) {
                    onUpdateCron(id: schedule.id, cron: cron);
                  }
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          )
        ],
      ),
    ),
  );
}

void showAddScheduleDialog(
  BuildContext context,
  Future<void> Function(
          {required String displayName,
          required String cron,
          required String prompt})
      onCreate,
) {
  final nameController = TextEditingController();
  final promptController = TextEditingController();
  var friendly = FriendlySchedule(frequency: ScheduleFrequency.daily);

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setState) => TerminalDialog(
        title: context.l10n.schedulerAddDialogTitle.toLowerCase(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.schedulerNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            _ScheduleFields(
              schedule: friendly,
              onChanged: (next) => setState(() => friendly = next),
            ),
            VSpace.x2,
            TerminalTextField(
              controller: promptController,
              label: context.l10n.schedulerPromptLabel,
              obscureText: false,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TerminalDialogActions(
            actions: [
              TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
                  () => Navigator.of(dialogContext).pop()),
              TerminalActionSpec(
                context.l10n.actionAdd,
                ActionKind.primary,
                () {
                  final name = nameController.text.trim();
                  final prompt = promptController.text.trim();
                  if (name.isEmpty || prompt.isEmpty) return;
                  onCreate(
                      displayName: name,
                      cron: _cronFromLocal(friendly),
                      prompt: prompt);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          )
        ],
      ),
    ),
  );
}
