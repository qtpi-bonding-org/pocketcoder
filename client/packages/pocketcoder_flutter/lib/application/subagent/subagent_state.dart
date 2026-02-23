import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/chat/subagent.dart';

part 'subagent_state.freezed.dart';

@freezed
class SubagentState with _$SubagentState {
  const factory SubagentState({
    @Default([]) List<Subagent> subagents,
    @Default(false) bool isLoading,
    String? error,
  }) = _SubagentState;
}
