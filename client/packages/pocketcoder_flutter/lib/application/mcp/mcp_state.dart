import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'mcp_state.freezed.dart';

@freezed
class McpState with _$McpState implements IUiFlowState {
  const McpState._();

  const factory McpState.initial() = _Initial;
  const factory McpState.loading() = _Loading;
  const factory McpState.loaded(List<McpServer> servers) = _Loaded;
  const factory McpState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
