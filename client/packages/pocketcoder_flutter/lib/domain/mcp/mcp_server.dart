import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

@freezed
class McpServer with _$McpServer {
  const factory McpServer({
    required String id,
    required String name,
    required McpServerStatus status,
    @JsonKey(name: 'requested_by') String? requestedBy,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    Map<String, dynamic>? config,
    String? catalog,
    String? reason,
    DateTime? created,
    DateTime? updated,
  }) = _McpServer;

  factory McpServer.fromJson(Map<String, dynamic> json) =>
      _$McpServerFromJson(json);
}

enum McpServerStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('denied')
  denied,
  @JsonValue('revoked')
  revoked,
  @JsonValue('')
  unknown,
}
