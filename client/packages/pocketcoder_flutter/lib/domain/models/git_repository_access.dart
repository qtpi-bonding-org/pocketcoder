class GitRepositoryAccess {
  final String id;
  final String? user,
      provider,
      repository,
      purpose,
      credentialMode,
      credential,
      requestedAccess,
      registrationStatus,
      status,
      lastError;
  const GitRepositoryAccess({
    required this.id,
    this.user,
    this.provider,
    this.repository,
    this.purpose,
    this.credentialMode,
    this.credential,
    this.requestedAccess,
    this.registrationStatus,
    this.status,
    this.lastError,
  });
  factory GitRepositoryAccess.fromJson(Map<String, dynamic> j) =>
      GitRepositoryAccess(
        id: '${j['id'] ?? ''}',
        user: j['user']?.toString(),
        provider: j['provider']?.toString(),
        repository: j['repository']?.toString(),
        purpose: j['purpose']?.toString(),
        credentialMode: j['credential_mode']?.toString(),
        credential: j['credential']?.toString(),
        requestedAccess: j['requested_access']?.toString(),
        registrationStatus: j['registration_status']?.toString(),
        status: j['status']?.toString(),
        lastError: j['last_error']?.toString(),
      );
}
