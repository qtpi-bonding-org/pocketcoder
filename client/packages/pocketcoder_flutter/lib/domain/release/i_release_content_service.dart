import 'dart:typed_data';

class ReleaseSelection {
  const ReleaseSelection({
    required this.channel,
    required this.sequence,
    required this.revocationSequence,
    required this.digest,
    required this.manifest,
  });

  final String channel;
  final int sequence;
  final int revocationSequence;
  final String digest;
  final Map<String, dynamic> manifest;

  String get serverVersion => manifest['serverVersion'] as String? ?? '';
  int get dataVersion => manifest['dataVersion'] as int? ?? 0;
}

/// Temporary source-compatibility name for dormant standard-Linux support.
/// The type no longer claims that Flutter established execution trust.
typedef VerifiedRelease = ReleaseSelection;

abstract interface class IReleaseContentService {
  /// A null channel defers to the implementation's own default (debug-only
  /// RELEASE_CHANNEL dart-define, 'stable' otherwise) -- see
  /// ReleaseContentService.resolve.
  Future<ReleaseSelection> resolve({String? channel});

  Future<Uint8List> fetchDocument(
    ReleaseSelection release,
    String documentId,
  );
}

class ReleaseContentException implements Exception {
  const ReleaseContentException(this.message, [this.cause, this.statusCode]);
  final String message;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() => 'ReleaseContentException: $message';
}
