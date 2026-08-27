const harnessAccountVisibilityPersonal = 'personal';
const harnessAccountVisibilityDeployment = 'deployment';

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
    required this.status,
    this.lastError,
  });

  final String id;
  final String status;
  final String? lastError;

  factory HarnessAuthAttempt.fromJson(Map<String, dynamic> json) {
    return HarnessAuthAttempt(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
    );
  }
}

class HarnessAuthStatus {
  const HarnessAuthStatus({
    required this.harness,
    required this.provider,
    required this.accountId,
    required this.accountName,
    required this.visibility,
    required this.credentialMode,
    required this.status,
    this.lastError,
    this.attempt,
    this.challenge,
  });

  final String harness;
  final String provider;
  final String accountId;
  final String accountName;
  final String visibility;
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
      provider: json['provider']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      visibility:
          json['visibility']?.toString() ?? harnessAccountVisibilityPersonal,
      credentialMode: json['mode']?.toString() ?? '',
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
      status == 'connecting' ||
      status == 'awaiting_input' ||
      status == 'starting';
  bool get isDisconnected => status == 'disconnected';
  bool get isDeploymentVisible =>
      visibility == harnessAccountVisibilityDeployment;
}
