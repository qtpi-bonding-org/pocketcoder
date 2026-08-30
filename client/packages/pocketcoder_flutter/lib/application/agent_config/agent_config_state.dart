import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';

part 'agent_config_state.freezed.dart';

@freezed
sealed class AgentConfigState with _$AgentConfigState, UiFlowStateMixin {
  const AgentConfigState._();

  const factory AgentConfigState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<PocoConfig> configs,
    @Default([]) List<Prompt> prompts,
    @Default([]) List<PermissionMode> permissionModes,
    Object? error,
  }) = _AgentConfigState;

  factory AgentConfigState.initial() => const AgentConfigState();
}
