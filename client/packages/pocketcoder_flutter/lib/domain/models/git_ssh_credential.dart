class GitSshCredential {
  final String id;
  final String? user,
      label,
      kind,
      source,
      algorithm,
      publicKey,
      fingerprint,
      status,
      lastError,
      materializedGeneration;
  const GitSshCredential({
    required this.id,
    this.user,
    this.label,
    this.kind,
    this.source,
    this.algorithm,
    this.publicKey,
    this.fingerprint,
    this.status,
    this.lastError,
    this.materializedGeneration,
  });
  factory GitSshCredential.fromJson(Map<String, dynamic> j) => GitSshCredential(
    id: '${j['id'] ?? ''}',
    user: j['user']?.toString(),
    label: j['label']?.toString(),
    kind: j['kind']?.toString(),
    source: j['source']?.toString(),
    algorithm: j['algorithm']?.toString(),
    publicKey: j['public_key']?.toString(),
    fingerprint: j['fingerprint']?.toString(),
    status: j['status']?.toString(),
    lastError: j['last_error']?.toString(),
    materializedGeneration: j['materialized_generation']?.toString(),
  );
}
