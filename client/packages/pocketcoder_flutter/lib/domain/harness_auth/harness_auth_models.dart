const harnessAccountVisibilityPersonal = 'personal';
const harnessAccountVisibilityDeployment = 'deployment';

enum HarnessAuthCodeDestination { browser, app, none, unknown }

class HarnessAuthChallenge {
  const HarnessAuthChallenge({
    this.kind,
    this.codeDestination = HarnessAuthCodeDestination.unknown,
    this.verificationUri,
    this.userCode,
    this.expiresAt,
    this.pollIntervalSeconds,
    this.legacyText,
    this.type = '',
    this.text = '',
    this.target,
    this.details,
  });

  final String? kind;
  final HarnessAuthCodeDestination codeDestination;
  final Uri? verificationUri;
  final String? userCode;
  final DateTime? expiresAt;
  final int? pollIntervalSeconds;
  final String? legacyText;

  // Deprecated compatibility fields used by older views.
  final String type;
  final String text;
  final String? target;
  final String? details;

  factory HarnessAuthChallenge.fromGenerated(
    dynamic generated,
  ) {
    final destination = generated.codeDestination?.name;
    return HarnessAuthChallenge(
      kind: generated.kind,
      verificationUri: _parseUri(generated.verificationUri),
      userCode: generated.userCode,
      expiresAt: generated.expiresAt,
      pollIntervalSeconds: generated.pollIntervalSeconds,
      codeDestination: switch (destination) {
        'browser' => HarnessAuthCodeDestination.browser,
        'app' => HarnessAuthCodeDestination.app,
        'none' => HarnessAuthCodeDestination.none,
        _ => HarnessAuthCodeDestination.unknown,
      },
      legacyText: generated.text,
      type: generated.type,
      text: generated.text,
      target: generated.target,
      details: generated.details,
    );
  }

  factory HarnessAuthChallenge.fromJson(Map<String, dynamic> json) {
    return HarnessAuthChallenge(
      kind: json['kind']?.toString(),
      codeDestination: switch (json['codeDestination']?.toString()) {
        'browser' => HarnessAuthCodeDestination.browser,
        'app' => HarnessAuthCodeDestination.app,
        'none' => HarnessAuthCodeDestination.none,
        _ => HarnessAuthCodeDestination.unknown,
      },
      verificationUri: _parseUri(json['verificationUri']?.toString()),
      userCode: json['userCode']?.toString(),
      expiresAt: _parseDateTime(json['expiresAt']?.toString()),
      pollIntervalSeconds: json['pollIntervalSeconds'] as int?,
      legacyText: json['text']?.toString(),
      type: json['type']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      target: json['target']?.toString(),
      details: json['details']?.toString(),
    );
  }

  static Uri? _parseUri(String? value) {
    if (value == null) return null;
    return Uri.tryParse(value);
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }
}

class HarnessAuthAttempt {
  const HarnessAuthAttempt({required this.id, required this.status, this.lastError});
  final String id;
  final String status;
  final String? lastError;

  factory HarnessAuthAttempt.fromJson(Map<String, dynamic> json) => HarnessAuthAttempt(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        lastError: json['lastError']?.toString(),
      );
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
      visibility: json['visibility']?.toString() ?? harnessAccountVisibilityPersonal,
      credentialMode: json['mode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
      attempt: attemptJson is Map<String, dynamic> ? HarnessAuthAttempt.fromJson(attemptJson) : null,
      challenge: challengeJson is Map<String, dynamic> ? HarnessAuthChallenge.fromJson(challengeJson) : null,
    );
  }
  bool get isConnected => status == 'connected';
  bool get isConnecting => status == 'connecting' || status == 'awaiting_input' || status == 'starting';
  bool get isDisconnected => status == 'disconnected';
  bool get isDeploymentVisible => visibility == harnessAccountVisibilityDeployment;
}
