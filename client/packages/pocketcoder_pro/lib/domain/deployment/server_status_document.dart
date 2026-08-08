import 'dart:convert';

class ServerStatusDocument {
  const ServerStatusDocument({
    required this.schema,
    required this.runId,
    required this.phase,
    required this.updatedAt,
    this.detail,
    this.sourceCommit,
    this.error,
  });

  final int schema;
  final String runId;
  final String phase;
  final String? detail;
  final String? sourceCommit;
  final DateTime updatedAt;
  final String? error;

  static ServerStatusDocument? tryParse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) return null;
      final updated = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
      final runId = value['runId']?.toString();
      final phase = value['phase']?.toString();
      if (updated == null || runId == null || phase == null) return null;
      return ServerStatusDocument(
        schema: value['schema'] is num ? (value['schema'] as num).toInt() : 1,
        runId: runId,
        phase: phase,
        updatedAt: updated,
        detail: value['detail']?.toString(),
        sourceCommit: value['sourceCommit']?.toString(),
        error: value['error']?.toString(),
      );
    } on Object {
      return null;
    }
  }
}
