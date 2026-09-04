import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

void showEditScheduleDialog(
  BuildContext context,
  ScheduleOwner schedule,
  Future<void> Function({required String id, required String displayName})
      onRename,
  Future<void> Function({required String id, required String cron})
      onUpdateCron,
) {
  final nameController = TextEditingController(text: schedule.displayName);
  final cronController = TextEditingController(text: schedule.cron ?? '');

  showDialog(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: context.l10n.schedulerEditDialogTitle(
        schedule.displayName.toUpperCase(),
      ),
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
          TerminalTextField(
            controller: cronController,
            label: context.l10n.schedulerCronLabel,
            obscureText: false,
          ),
        ],
      ),
      actions: [
        TerminalDialogActions(
          confirmLabel: context.l10n.schedulerSaveButton,
          onConfirm: () {
            final name = nameController.text.trim();
            final cron = cronController.text.trim();
            if (name.isEmpty || cron.isEmpty) {
              return;
            }
            if (name != schedule.displayName) {
              onRename(id: schedule.id, displayName: name);
            }
            if (cron != (schedule.cron ?? '')) {
              onUpdateCron(id: schedule.id, cron: cron);
            }
            Navigator.of(dialogContext).pop();
          },
          cancelLabel: context.l10n.actionCancel,
          onCancel: () => Navigator.of(dialogContext).pop(),
        ),
      ],
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
  final cronController = TextEditingController();
  final promptController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: context.l10n.schedulerAddDialogTitle,
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
          TerminalTextField(
            controller: cronController,
            label: context.l10n.schedulerCronLabel,
            obscureText: false,
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
          confirmLabel: context.l10n.actionAdd,
          onConfirm: () {
            final name = nameController.text.trim();
            final cron = cronController.text.trim();
            final prompt = promptController.text.trim();
            if (name.isEmpty || cron.isEmpty || prompt.isEmpty) {
              return;
            }
            onCreate(displayName: name, cron: cron, prompt: prompt);
            Navigator.of(dialogContext).pop();
          },
          cancelLabel: context.l10n.actionCancel,
          onCancel: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}
