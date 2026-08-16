/// Certificate state reported by the deployment's public status snapshot.
enum ServerTlsState { pending, ready, rateLimited, failed, unknown }

final class ServerTlsStatus {
  const ServerTlsStatus({
    required this.state,
    this.hostname,
    this.issuer,
    this.expiresAt,
    this.reason,
  });

  final ServerTlsState state;
  final String? hostname;
  final String? issuer;
  final String? expiresAt;
  final String? reason;

  bool get isTrusted => state == ServerTlsState.ready;
  bool get isRateLimited => state == ServerTlsState.rateLimited;

  factory ServerTlsStatus.fromJson(Map<String, dynamic>? json) {
    final value = json?['state'] as String?;
    final state = switch (value) {
      'pending' => ServerTlsState.pending,
      'ready' => ServerTlsState.ready,
      'rate_limited' => ServerTlsState.rateLimited,
      'failed' => ServerTlsState.failed,
      _ => ServerTlsState.unknown,
    };
    return ServerTlsStatus(
      state: state,
      hostname: json?['hostname'] as String?,
      issuer: json?['issuer'] as String?,
      expiresAt: json?['expiresAt'] as String?,
      reason: json?['reason'] as String?,
    );
  }
}

/// Parses the deployment snapshot without making TLS state a second readiness
/// protocol. Unknown top-level fields remain available to callers that need
/// forward compatibility.
final class ServerStatusSnapshot {
  const ServerStatusSnapshot({required this.tls, required this.raw});

  final ServerTlsStatus tls;
  final Map<String, dynamic> raw;

  factory ServerStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return ServerStatusSnapshot(
      tls: ServerTlsStatus.fromJson(json['tls'] as Map<String, dynamic>?),
      raw: Map.unmodifiable(json),
    );
  }
}
