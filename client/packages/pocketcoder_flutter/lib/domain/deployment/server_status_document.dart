import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';

class ServerStatusDocument {
  ServerStatusDocument({
    required this.schema,
    required this.runId,
    required this.phase,
    required this.updatedAt,
    required Map<String, Object?> raw,
    this.detail,
    this.sourceCommit,
    this.error,
    this.sshHostKey,
    this.tls,
  }) : raw = Map<String, Object?>.unmodifiable(raw);

  final int schema;
  final String runId;
  final String phase;
  final String? detail;
  final String? sourceCommit;
  final DateTime updatedAt;
  final String? error;
  final ServerSshHostKey? sshHostKey;

  /// Caddy's certificate state, when the server has published one (schema 2+).
  /// Absent on older documents or before the first TLS check has run.
  final ServerTlsStatus? tls;

  /// The complete status payload, retained so newer server fields are not
  /// discarded by an older client that does not understand them yet.
  final Map<String, Object?> raw;

  static ServerStatusDocument? tryParse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) return null;
      final updated = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
      final runId = value['runId']?.toString();
      final phase = value['phase']?.toString();
      if (updated == null || runId == null || phase == null) return null;
      final sshHostKeyValue = value['sshHostKey'];
      final sshHostKey = sshHostKeyValue is Map<String, dynamic>
          ? ServerSshHostKey.tryParse(sshHostKeyValue)
          : null;
      final tlsValue = value['tls'];
      final tls = tlsValue is Map<String, dynamic>
          ? ServerTlsStatus.fromJson(tlsValue)
          : null;
      return ServerStatusDocument(
        schema: value['schema'] is num ? (value['schema'] as num).toInt() : 1,
        runId: runId,
        phase: phase,
        updatedAt: updated,
        detail: value['detail']?.toString(),
        sourceCommit: value['sourceCommit']?.toString(),
        error: value['error']?.toString(),
        sshHostKey: sshHostKey,
        tls: tls,
        raw: Map<String, Object?>.from(value),
      );
    } on Object {
      return null;
    }
  }
}

class ServerSshHostKey {
  const ServerSshHostKey({required this.type, required this.fingerprint});

  static final _md5Fingerprint = RegExp(
    r'^MD5:(?:[0-9a-f]{2}:){15}[0-9a-f]{2}$',
  );

  final String type;
  final String fingerprint;

  static ServerSshHostKey? tryParse(Map<String, dynamic> value) {
    final type = value['type']?.toString() ?? '';
    final fingerprint = value['fingerprint']?.toString() ?? '';
    if (type != 'ssh-ed25519' || !_md5Fingerprint.hasMatch(fingerprint)) {
      return null;
    }
    return ServerSshHostKey(type: type, fingerprint: fingerprint);
  }
}
