enum ServerReadinessStatus {
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
