import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/skills/skills_cubit.dart';
import 'package:pocketcoder_flutter/application/skills/skills_state.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/skills/widgets/skill_dialogs.dart';
import 'package:pocketcoder_flutter/presentation/skills/widgets/skills_view.dart';

class SkillsAdapter extends CubitAdapter<SkillsCubit, SkillsState> {
  const SkillsAdapter({super.key});

  static SkillsState _selectState(SkillsState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<SkillsCubit, SkillsState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<SkillsCubit>();
    return UiFlowListener<SkillsCubit, SkillsState>(
      child: ValueListenableBuilder<SkillsState>(
        valueListenable: state,
        builder: (context, value, _) => SkillsView(
          data: switch (value.status) {
            UiFlowStatus.loading => const SkillsViewData(isLoading: true),
            UiFlowStatus.failure => SkillsViewData(error: value.error),
            UiFlowStatus.success => SkillsViewData(skills: value.skills),
            UiFlowStatus.idle => const SkillsViewData(),
          },
          onAdd: () => _showAddDialog(context, cubit),
          onEdit: (skill) => _showEditDialog(context, cubit, skill),
          onDelete: cubit.deleteSkill,
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, SkillsCubit cubit, Skill skill) {
    showDialog<void>(
      context: context,
      builder: (_) => SkillEditorDialog(
        skill: skill,
        onSubmit: (name, description, content) => cubit.updateSkill(
          id: skill.id,
          name: name,
          description: description,
          content: content,
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, SkillsCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (_) => StreamBuilder(
        stream: cubit.watchConfigs(),
        builder: (context, snapshot) => AddSkillDialog(
          configs: snapshot.data ?? const [],
          onSubmit: (name, description, content, global, projectDir) =>
              cubit.createSkill(
            name: name,
            description: description,
            content: content,
            global: global,
            projectDir: projectDir,
          ),
        ),
      ),
    );
  }
}
