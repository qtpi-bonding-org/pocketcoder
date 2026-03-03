import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';

part 'sandbox_agent_state.freezed.dart';

@freezed
class SandboxAgentState with _$SandboxAgentState {
  const factory SandboxAgentState({
    @Default([]) List<SandboxAgent> sandboxAgents,
    @Default(false) bool isLoading,
    String? error,
  }) = _SandboxAgentState;
}
