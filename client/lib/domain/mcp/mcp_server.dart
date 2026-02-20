import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

@freezed
class McpServer with _$McpServer {
  const factory McpServer({
    required String id,
    required String name,
    required String command,
    List<String>? args,
    Map<String, String>? env,
    @JsonKey(name: 'status') required McpServerStatus status,
    @JsonKey(name: 'last_seen') DateTime? lastSeen,
    @JsonKey(name: 'is_enabled') @Default(true) bool isEnabled,
    DateTime? created,
    DateTime? updated,
  }) = _McpServer;

  factory McpServer.fromJson(Map<String, dynamic> json) =>
      _$McpServerFromJson(json);
}

enum McpServerStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
  @JsonValue('error')
  error,
  @JsonValue('')
  unknown,
}
