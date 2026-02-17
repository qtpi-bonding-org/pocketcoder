class SessionResolution {
  final String sessionId;
  final String host;
  final int port;
  final String? sessionName;
  final Map<String, dynamic>? metadata;

  SessionResolution({
    required this.sessionId,
    required this.host,
    required this.port,
    this.sessionName,
    this.metadata,
  });

  factory SessionResolution.fromJson(Map<String, dynamic> json) {
    return SessionResolution(
      sessionId: json['session_id'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      sessionName: json['session_name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'host': host,
      'port': port,
      'session_name': sessionName,
      'metadata': metadata,
    };
  }
}