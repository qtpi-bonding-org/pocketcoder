import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'mcp_state.freezed.dart';

@freezed
sealed class McpState with _$McpState, UiFlowStateMixin {
  const McpState._();

  const factory McpState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<McpServer> servers,
    Object? error,
  }) = _McpState;
}
