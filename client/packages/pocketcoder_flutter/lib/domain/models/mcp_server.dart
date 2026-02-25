import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

@freezed
class McpServer with _$McpServer {
  const factory McpServer({
    required String id,
    required String name,
    required McpServerStatus status,
    String? requestedBy,
    String? approvedBy,
    DateTime? approvedAt,
    dynamic config,
    String? catalog,
    String? reason,
  }) = _McpServer;

  factory McpServer.fromRecord(RecordModel record) =>
      McpServer.fromJson(record.toJson());

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
  @JsonValue('__unknown__')
  unknown,
}
