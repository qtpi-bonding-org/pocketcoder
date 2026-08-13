import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'adapters/scheduler_adapter.dart';

class SchedulerScreen extends StatelessWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SchedulerCubit>()..loadSchedules(),
      child: const SchedulerAdapter(),
    );
  }
}

class SchedulerView extends StatelessWidget {
  const SchedulerView({
    super.key,
    required this.state,
    required this.onPause,
    required this.onUnpause,
    required this.onRunNow,
    required this.onDelete,
    required this.onRename,
    required this.onUpdateCron,
    required this.onCreate,
  });

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
        child: Builder(
          builder: (context) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (schedules) => ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: TerminalButton(
                      label: context.l10n.schedulerAddButton,
                      onTap: () => _showAddScheduleDialog(context),
                    ),
                  ),
                  for (final schedule in schedules)
                    _buildScheduleItem(context, schedule),
                  if (schedules.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.space * 4),
                        child: TerminalText(
                          context.l10n.schedulerNoSchedules,
                          alpha: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (msg) => Center(
                child:
                    Text('ERROR: $msg', style: TextStyle(color: colors.error)),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, ScheduleOwner schedule) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TerminalText(
                  schedule.displayName.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
              ),
              if (schedule.paused ?? false)
                TerminalText.mini(context.l10n.schedulerPausedBadge,
                    alpha: 0.5),
            ],
          ),
          VSpace.x1,
          TerminalText.mini(schedule.cron ?? '', alpha: 0.6),
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: (schedule.paused ?? false)
                      ? context.l10n.schedulerResumeButton
                      : context.l10n.schedulerPauseButton,
                  isPrimary: false,
                  onTap: () => (schedule.paused ?? false)
                      ? onUnpause(schedule.id)
                      : onPause(schedule.id),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: context.l10n.schedulerRunNowButton,
                  isPrimary: false,
                  onTap: () => onRunNow(schedule.id),
                ),
              ),
            ],
          ),
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: context.l10n.schedulerEditButton,
                  isPrimary: false,
                  onTap: () => _showEditScheduleDialog(context, schedule),
                ),
              ),
              HSpace.x2,
              TerminalButton(
                label: context.l10n.schedulerDeleteButton,
                color: context.colorScheme.error,
                onTap: () => onDelete(schedule.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, ScheduleOwner schedule) {
    final colors = Theme.of(context).colorScheme;
    final nameController = TextEditingController(text: schedule.displayName);
    final cronController = TextEditingController(text: schedule.cron ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n
            .schedulerEditDialogTitle(schedule.displayName.toUpperCase()),
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
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
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
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.schedulerSaveButton),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final cron = cronController.text.trim();
              final prompt = promptController.text.trim();
              if (name.isEmpty || cron.isEmpty || prompt.isEmpty) {
                return;
              }
              onCreate(displayName: name, cron: cron, prompt: prompt);
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionAdd),
          ),
        ],
      ),
    );
  }
}
