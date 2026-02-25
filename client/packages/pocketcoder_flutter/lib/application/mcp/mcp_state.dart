import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

part 'mcp_state.freezed.dart';

@freezed
class McpState with _$McpState {
  const factory McpState.initial() = _Initial;
  const factory McpState.loading() = _Loading;
  const factory McpState.loaded(List<McpServer> servers) = _Loaded;
  const factory McpState.error(String message) = _Error;
}
