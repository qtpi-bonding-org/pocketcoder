class PermissionEvaluation {
  final bool allowed;
  final String? reason;
  final Map<String, dynamic>? metadata;

  PermissionEvaluation({
    required this.allowed,
    this.reason,
    this.metadata,
  });

  factory PermissionEvaluation.fromJson(Map<String, dynamic> json) {
    return PermissionEvaluation(
      allowed: json['allowed'] as bool,
      reason: json['reason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowed': allowed,
      'reason': reason,
      'metadata': metadata,
    };
  }
}