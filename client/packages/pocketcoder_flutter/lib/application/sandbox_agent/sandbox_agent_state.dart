import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';

part 'sandbox_agent_state.freezed.dart';

@freezed
sealed class SandboxAgentState with _$SandboxAgentState, UiFlowStateMixin {
  const SandboxAgentState._();

  const factory SandboxAgentState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<SandboxAgent> sandboxAgents,
    Object? error,
  }) = _SandboxAgentState;
}
