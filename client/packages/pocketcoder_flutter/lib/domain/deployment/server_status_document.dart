import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';

class ServerStatusDocument {
  ServerStatusDocument({
    required this.schema,
    required this.runId,
    required this.operation,
    required this.updatedAt,
    required Map<String, Object?> raw,
    this.detail,
    this.sourceCommit,
    this.errorCode,
    this.errorMessage,
    this.attempt = 1,
    this.maxAttempts = 1,
    this.sshHostKey,
    this.tls,
  }) : raw = Map<String, Object?>.unmodifiable(raw);

  final int schema;
  final String runId;
  final String operation;
  final String? detail;
  final String? sourceCommit;
  final DateTime updatedAt;
  final String? errorCode;
  final String? errorMessage;

  /// How many times the enclosing retry-wrapped unit (currently: the
  /// whole `pocketcoder-release install` invocation) has been attempted.
  /// Absent on the wire means not retry-wrapped -- defaults to 1/1, which
  /// preserves always-terminal error handling for those steps.
  final int attempt;
  final int maxAttempts;

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
      final operation = value['operation']?.toString();
      if (updated == null || runId == null || operation == null) return null;
      final sshHostKeyValue = value['sshHostKey'];
      final sshHostKey = sshHostKeyValue is Map<String, dynamic>
          ? ServerSshHostKey.tryParse(sshHostKeyValue)
          : null;
      final tlsValue = value['tls'];
      final tls = tlsValue is Map<String, dynamic>
          ? ServerTlsStatus.fromJson(tlsValue)
          : null;
      final attemptValue = value['attempt'];
      final maxAttemptsValue = value['maxAttempts'];
      return ServerStatusDocument(
        schema: value['schema'] is num ? (value['schema'] as num).toInt() : 1,
        runId: runId,
        operation: operation,
        updatedAt: updated,
        detail: value['detail']?.toString(),
        sourceCommit: value['sourceCommit']?.toString(),
        errorCode: value['errorCode']?.toString(),
        errorMessage: value['errorMessage']?.toString(),
        attempt: attemptValue is num ? attemptValue.toInt() : 1,
        maxAttempts: maxAttemptsValue is num ? maxAttemptsValue.toInt() : 1,
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

  // dartssh2's onVerifyHostKey expects the literal UTF-8 bytes of
  // "SHA256:<base64>" -- see SshRootCommandRunner._parseFingerprint. This
  // field was MD5-formatted (from status.sh) until that mismatch was
  // found live: the comparison could never succeed, so every root SSH
  // command silently failed to connect.
  static final _sha256Fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]+$');

  final String type;
  final String fingerprint;

  static ServerSshHostKey? tryParse(Map<String, dynamic> value) {
    final type = value['type']?.toString() ?? '';
    final fingerprint = value['fingerprint']?.toString() ?? '';
    if (type != 'ssh-ed25519' || !_sha256Fingerprint.hasMatch(fingerprint)) {
      return null;
    }
    return ServerSshHostKey(type: type, fingerprint: fingerprint);
  }
}
