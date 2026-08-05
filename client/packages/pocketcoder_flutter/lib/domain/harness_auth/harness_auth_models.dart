class HarnessAuthChallenge {
  const HarnessAuthChallenge({
    required this.type,
    required this.text,
    this.target,
    this.details,
  });

  final String type;
  final String text;
  final String? target;
  final String? details;

  factory HarnessAuthChallenge.fromJson(Map<String, dynamic> json) {
    return HarnessAuthChallenge(
      type: json['type']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      target: json['target']?.toString(),
      details: json['details']?.toString(),
    );
  }
}
class HarnessAuthAttempt {
  const HarnessAuthAttempt({
    required this.id,
    required this.provider,
    required this.status,
    this.lastError,
  });

  final String id;
  final String provider;
  final String status;
  final String? lastError;

  factory HarnessAuthAttempt.fromJson(Map<String, dynamic> json) {
    return HarnessAuthAttempt(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
    );
  }
}

class HarnessAuthStatus {
  const HarnessAuthStatus({
    required this.harness,
    required this.scopeKind,
    required this.scopeId,
    required this.bindingId,
    required this.credentialMode,
    required this.status,
    this.lastError,
    this.attempt,
    this.challenge,
  });

  final String harness;
  final String scopeKind;
  final String scopeId;
  final String bindingId;
  final String credentialMode;
  final String status;
  final String? lastError;
  final HarnessAuthAttempt? attempt;
  final HarnessAuthChallenge? challenge;

  factory HarnessAuthStatus.fromJson(Map<String, dynamic> json) {
    final attemptJson = json['attempt'];
    final challengeJson = json['challenge'];

    return HarnessAuthStatus(
      harness: json['harness']?.toString() ?? '',
      scopeKind: json['scopeKind']?.toString() ?? '',
      scopeId: json['scopeId']?.toString() ?? '',
      bindingId: json['bindingId']?.toString() ?? '',
      credentialMode: json['credentialMode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
      attempt: attemptJson is Map<String, dynamic>
          ? HarnessAuthAttempt.fromJson(attemptJson)
          : null,
      challenge: challengeJson is Map<String, dynamic>
          ? HarnessAuthChallenge.fromJson(challengeJson)
          : null,
    );
  }

  bool get isConnected => status == 'connected';
  bool get isConnecting =>
      status == 'connecting' || status == 'awaiting_input' || status == 'starting';
  bool get isDisconnected => status == 'disconnected';
  bool get needsApiKey => status == 'needs_api_key';
}
