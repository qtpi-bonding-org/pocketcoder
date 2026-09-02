enum ServerReadinessStatus {
  /// Q1 has no answer yet -- still checking whether anything needs
  /// resuming. Never a terminal state a router should navigate onto;
  /// callers should keep showing the boot screen while this is current.
  resolving,
  notProvisioned,
  provisioning,
  ready,
  resumeUnrecoverable,
}

class ServerReadinessSnapshot {
  const ServerReadinessSnapshot({required this.status, this.instanceId});

  final ServerReadinessStatus status;
  final String? instanceId;
}

abstract interface class IServerReadinessCheck {
  ServerReadinessSnapshot get current;
  Stream<ServerReadinessSnapshot> get readinessChanges;

  Future<void> initialize();
  Future<void> retry();
}
