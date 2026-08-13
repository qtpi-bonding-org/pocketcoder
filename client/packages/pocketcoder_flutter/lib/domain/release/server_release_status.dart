enum ServerReleaseStatus {
  current,
  updateAvailable,
  criticalReleaseWarning,
  unknown,
}

class ServerReleaseStatusSnapshot {
  const ServerReleaseStatusSnapshot({
    required this.status,
    required this.currentVersion,
    required this.currentDataVersion,
    required this.currentReleaseDigest,
    required this.checkedAt,
    this.availableVersion,
    this.availableDataVersion,
    this.availableReleaseDigest,
    this.downloadBytes,
    this.requiredDiskBytes,
    this.normalRollbackAvailableAfterSuccess,
    this.reasonCode,
    this.summary,
  });

  final ServerReleaseStatus status;
  final String currentVersion;
  final int currentDataVersion;
  final String currentReleaseDigest;
  final DateTime? checkedAt;
  final String? availableVersion;
  final int? availableDataVersion;
  final String? availableReleaseDigest;
  final int? downloadBytes;
  final int? requiredDiskBytes;
  final bool? normalRollbackAvailableAfterSuccess;
  final String? reasonCode;
  final String? summary;

  bool get crossesDataVersion =>
      availableDataVersion != null &&
      availableDataVersion != currentDataVersion;

  bool get needsAttention =>
      status == ServerReleaseStatus.updateAvailable ||
      status == ServerReleaseStatus.criticalReleaseWarning;

  factory ServerReleaseStatusSnapshot.fromStatus(
    Map<String, dynamic> value,
  ) {
    final release = _map(value['current']);
    final metadata = _map(value['metadataStatus']);
    return ServerReleaseStatusSnapshot(
      status: _status(metadata['status']),
      currentVersion: _string(
        metadata['currentVersion'] ?? release['serverVersion'],
      ),
      currentDataVersion: _integer(
        metadata['currentDataVersion'] ?? release['dataVersion'],
      ),
      currentReleaseDigest: _string(
        metadata['currentReleaseDigest'] ?? release['releaseDigest'],
      ),
      checkedAt: DateTime.tryParse(_string(metadata['checkedAt'])),
      availableVersion: _nullableString(metadata['availableVersion']),
      availableDataVersion: _nullableInteger(
        metadata['availableDataVersion'],
      ),
      availableReleaseDigest: _nullableString(
        metadata['availableReleaseDigest'],
      ),
      downloadBytes: _nullableInteger(metadata['downloadBytes']),
      requiredDiskBytes: _nullableInteger(metadata['requiredDiskBytes']),
      normalRollbackAvailableAfterSuccess:
          metadata['normalRollbackAvailableAfterSuccess'] as bool?,
      reasonCode: _nullableString(metadata['reasonCode']),
      summary: _nullableString(metadata['summary']),
    );
  }

  static ServerReleaseStatus _status(Object? value) => switch (value) {
        'current' => ServerReleaseStatus.current,
        'update-available' => ServerReleaseStatus.updateAvailable,
        'critical-release-warning' =>
          ServerReleaseStatus.criticalReleaseWarning,
        _ => ServerReleaseStatus.unknown,
      };

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static String _string(Object? value) => value is String ? value : '';

  static String? _nullableString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int _integer(Object? value) => value is int ? value : 0;

  static int? _nullableInteger(Object? value) => value is int ? value : null;
}
