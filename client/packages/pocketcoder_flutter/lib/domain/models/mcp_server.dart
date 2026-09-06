import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

@freezed
abstract class McpServer with _$McpServer {
  const factory McpServer({
    required String id,
    required String name,
    @JsonKey(unknownEnumValue: McpServerStatus.unknown)
    required McpServerStatus status,
    String? requestedBy,
    String? approvedBy,
    DateTime? approvedAt,
    dynamic config,
    String? catalog,
    String? reason,
    String? image,
    dynamic configSchema,
    String? oauthProvider,
    String? oauthTokenEnvVar,
    DateTime? created,
    DateTime? updated,
    @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
    McpServerAcpTransport? acpTransport,
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

enum McpServerAcpTransport {
  @JsonValue('http')
  http,
  @JsonValue('sse')
  sse,
  @JsonValue('stdio')
  stdio,
  @JsonValue('__unknown__')
  unknown,
}
