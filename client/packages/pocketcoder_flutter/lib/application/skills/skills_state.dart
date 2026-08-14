import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';

part 'skills_state.freezed.dart';

@freezed
sealed class SkillsState with _$SkillsState, UiFlowStateMixin {
  const SkillsState._();

  const factory SkillsState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<Skill> skills,
    Object? error,
  }) = _SkillsState;
}
