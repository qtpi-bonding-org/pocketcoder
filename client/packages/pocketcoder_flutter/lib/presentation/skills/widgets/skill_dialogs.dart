import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';

class SkillEditorDialog extends StatefulWidget {
  const SkillEditorDialog({super.key, this.skill, required this.onSubmit});

  final Skill? skill;
  final void Function(String name, String description, String content) onSubmit;

  @override
  State<SkillEditorDialog> createState() => _SkillEditorDialogState();
}

class _SkillEditorDialogState extends State<SkillEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    final skill = widget.skill;
    _name = TextEditingController(text: skill?.name ?? '');
    _description = TextEditingController(text: skill?.description ?? '');
    _content = TextEditingController(text: skill?.content ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.skill != null;
    final skillName = widget.skill?.name ?? '';
    return TerminalDialog(
      title: editing
          ? context.l10n
              .skillsEditDialogTitle(skillName)
              .toLowerCase()
          : context.l10n.skillsAddDialogTitle.toLowerCase(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalTextField(
              controller: _name,
              label: context.l10n.skillsNameLabel,
              obscureText: false),
          VSpace.x2,
          TerminalTextField(
              controller: _description,
              label: context.l10n.skillsDescriptionLabel,
              obscureText: false),
          VSpace.x2,
          TerminalTextField(
              controller: _content,
              label: context.l10n.skillsContentLabel,
              obscureText: false,
              maxLines: 8),
        ],
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
              () => Navigator.of(context).pop()),
          TerminalActionSpec(
              editing ? context.l10n.skillsSaveButton : context.l10n.actionAdd,
              ActionKind.primary, () {
            final name = _name.text.trim();
            final description = _description.text.trim();
            final content = _content.text.trim();
            if (name.isEmpty || description.isEmpty || content.isEmpty) return;
            widget.onSubmit(name, description, content);
            Navigator.of(context).pop();
          }),
        ]),
      ],
    );
  }
}

class AddSkillDialog extends StatefulWidget {
  const AddSkillDialog(
      {super.key, required this.configs, required this.onSubmit});

  final List<PocoConfig> configs;
  final void Function(String name, String description, String content,
      bool global, String? projectDir) onSubmit;

  @override
  State<AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<AddSkillDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _content = TextEditingController();
  bool _global = true;
  PocoConfig? _selectedConfig;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configs = widget.configs
        .where((config) =>
            config.workspaceFolders is List &&
            (config.workspaceFolders as List).isNotEmpty)
        .toList();
    final selected = configs.contains(_selectedConfig) ? _selectedConfig : null;
    return TerminalDialog(
      title: context.l10n.skillsAddDialogTitle.toLowerCase(),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
                controller: _name,
                label: context.l10n.skillsNameLabel,
                obscureText: false),
            VSpace.x2,
            TerminalTextField(
                controller: _description,
                label: context.l10n.skillsDescriptionLabel,
                obscureText: false),
            VSpace.x2,
            TerminalTextField(
                controller: _content,
                label: context.l10n.skillsContentLabel,
                obscureText: false,
                maxLines: 8),
            VSpace.x2,
            Row(children: [
              Expanded(
                  child: TerminalButton(
                      label: context.l10n.skillsGlobalLabel,
                      kind: _global ? ActionKind.primary : ActionKind.neutral,
                      onTap: () => setState(() {
                            _global = true;
                            _selectedConfig = null;
                          }))),
              HSpace.x2,
              Expanded(
                  child: TerminalButton(
                      label: context.l10n.skillsProjectLabel,
                      kind: !_global ? ActionKind.primary : ActionKind.neutral,
                      onTap: configs.isEmpty
                          ? () {}
                          : () => setState(() {
                                _global = false;
                                _selectedConfig ??= configs.first;
                              }))),
            ]),
            if (!_global && configs.isEmpty) ...[
              VSpace.x1,
              Text(context.l10n.skillsNoEligibleConfig)
            ],
            if (!_global && configs.isNotEmpty) ...[
              VSpace.x1,
              DetailRow(
                label: context.l10n.skillsProjectLabel,
                value: selected?.name ?? '',
                affordance: RowAffordance.expand,
                onTap: () => showTerminalListPicker<PocoConfig>(
                  context: context,
                  title: context.l10n.skillsProjectLabel,
                  items: configs,
                  itemBuilder: (_, config) => TerminalText(config.name, role: TextRole.label),
                  selected: selected,
                  emptyLabel: 'no projects',
                  cancelLabel: 'cancel',
                ).then((config) {
                  if (config != null) setState(() => _selectedConfig = config);
                }),
              ),
            ],
          ]),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
              () => Navigator.of(context).pop()),
          TerminalActionSpec(context.l10n.actionAdd, ActionKind.primary, () {
            final name = _name.text.trim();
            final description = _description.text.trim();
            final content = _content.text.trim();
            if (name.isEmpty || description.isEmpty || content.isEmpty) {
              return;
            }
            String? projectDir;
            if (!_global) {
              final folders = _selectedConfig?.workspaceFolders;
              if (folders is! List || folders.isEmpty) return;
              projectDir = folders.first as String;
            }
            widget.onSubmit(name, description, content, _global, projectDir);
            Navigator.of(context).pop();
          }),
        ]),
      ],
    );
  }
}
